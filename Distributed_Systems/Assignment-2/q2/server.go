package main

import (
	"context"
	"fmt"
	"log"
	"net"
	"os"
	"sync"
	"time"

	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	pb "task_queue_system/taskqueue"
)

// ─── Internal state ────────────────────────────────────────────────────────

type queuedTask struct {
	id          string
	taskType    pb.TaskType
	payload     string
	taskStatus  string // "Queued" | "Processing" | "Completed" | "Failed"
	workerID    string
	arrivalTime time.Time
}

type workerState struct {
	id            string
	workerType    pb.WorkerType
	currentTaskID string
	lastHeartbeat time.Time
	dead          bool
	taskChan      chan *pb.Task // buffered(1): server pushes task here
	doneChan      chan struct{} // closed when worker is marked dead
}

// ─── Server ────────────────────────────────────────────────────────────────

type taskQueueServer struct {
	pb.UnimplementedTaskQueueServiceServer

	mu            sync.Mutex
	tasks         map[string]*queuedTask
	cpuQueue      []*queuedTask
	ioQueue       []*queuedTask
	workers       map[string]*workerState
	taskCounter   int
	workerCounter int
}

func newTaskQueueServer() *taskQueueServer {
	s := &taskQueueServer{
		tasks:   make(map[string]*queuedTask),
		workers: make(map[string]*workerState),
	}
	go s.heartbeatChecker()
	return s
}

// ─── Job Client RPCs ───────────────────────────────────────────────────────

func (s *taskQueueServer) SubmitTask(_ context.Context, req *pb.TaskRequest) (*pb.TaskResponse, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	s.taskCounter++
	taskID := fmt.Sprintf("T%d", s.taskCounter)

	task := &queuedTask{
		id:          taskID,
		taskType:    req.Type,
		payload:     req.Payload,
		taskStatus:  "Queued",
		arrivalTime: time.Now(),
	}
	s.tasks[taskID] = task

	if req.Type == pb.TaskType_CPU {
		s.cpuQueue = append(s.cpuQueue, task)
	} else {
		s.ioQueue = append(s.ioQueue, task)
	}

	typeStr := taskTypeString(req.Type)
	log.Printf("[Server] Task %s queued (%s, payload=%s)", taskID, typeStr, req.Payload)

	s.tryAssignToAvailableWorkers()

	return &pb.TaskResponse{TaskId: taskID}, nil
}

func (s *taskQueueServer) GetTaskStatus(_ context.Context, req *pb.TaskStatusRequest) (*pb.TaskStatusResponse, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	task, ok := s.tasks[req.TaskId]
	if !ok {
		return nil, status.Errorf(codes.NotFound, "task %s not found", req.TaskId)
	}

	return &pb.TaskStatusResponse{
		TaskId:   task.id,
		Status:   task.taskStatus,
		WorkerId: task.workerID,
	}, nil
}

// ─── Worker RPCs ───────────────────────────────────────────────────────────

func (s *taskQueueServer) RegisterWorker(_ context.Context, cfg *pb.WorkerConfig) (*pb.WorkerId, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	s.workerCounter++
	workerID := fmt.Sprintf("W%d", s.workerCounter)

	worker := &workerState{
		id:            workerID,
		workerType:    cfg.Type,
		lastHeartbeat: time.Now(),
		taskChan:      make(chan *pb.Task, 1),
		doneChan:      make(chan struct{}),
	}
	s.workers[workerID] = worker

	log.Printf("[Server] Worker %s registered (type: %s)", workerID, workerTypeString(cfg.Type))

	// Try to assign an already-queued task immediately.
	s.tryAssignTaskToWorker(worker)

	return &pb.WorkerId{WorkerId: workerID}, nil
}

func (s *taskQueueServer) RequestTask(req *pb.WorkerId, stream pb.TaskQueueService_RequestTaskServer) error {
	s.mu.Lock()
	worker, ok := s.workers[req.WorkerId]
	if !ok {
		s.mu.Unlock()
		return status.Errorf(codes.NotFound, "worker %s not found", req.WorkerId)
	}
	taskChan := worker.taskChan
	doneChan := worker.doneChan
	s.mu.Unlock()

	log.Printf("[Server] Worker %s opened task stream", req.WorkerId)

	for {
		select {
		case task, open := <-taskChan:
			if !open {
				return status.Errorf(codes.Unavailable, "worker %s channel closed", req.WorkerId)
			}
			log.Printf("[Server] Sending task %s to worker %s", task.TaskId, req.WorkerId)
			if err := stream.Send(task); err != nil {
				return err
			}

		case <-doneChan:
			log.Printf("[Server] Worker %s stream terminated (worker dead)", req.WorkerId)
			return status.Errorf(codes.Unavailable, "worker %s marked as dead", req.WorkerId)

		case <-stream.Context().Done():
			log.Printf("[Server] Worker %s stream context canceled", req.WorkerId)
			return stream.Context().Err()
		}
	}
}

func (s *taskQueueServer) SendHeartbeat(_ context.Context, hb *pb.Heartbeat) (*pb.Acknowledge, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	worker, ok := s.workers[hb.WorkerId]
	if !ok {
		return &pb.Acknowledge{Success: false, Message: "worker not found"}, nil
	}
	if worker.dead {
		return &pb.Acknowledge{Success: false, Message: "worker is dead"}, nil
	}

	worker.lastHeartbeat = time.Now()
	return &pb.Acknowledge{Success: true, Message: "ok"}, nil
}

func (s *taskQueueServer) UpdateTaskStatus(_ context.Context, upd *pb.TaskStatusUpdate) (*pb.Acknowledge, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	task, ok := s.tasks[upd.TaskId]
	if !ok {
		return &pb.Acknowledge{Success: false, Message: "task not found"}, nil
	}

	task.taskStatus = upd.Status
	log.Printf("[Server] Task %s → %s (worker %s)", upd.TaskId, upd.Status, upd.WorkerId)

	// Free the worker and try to give it the next task.
	if upd.Status == "Completed" || upd.Status == "Failed" {
		if worker, wok := s.workers[upd.WorkerId]; wok && !worker.dead {
			worker.currentTaskID = ""
			s.tryAssignTaskToWorker(worker)
		}
	}

	return &pb.Acknowledge{Success: true, Message: "ok"}, nil
}

// ─── Internal helpers ──────────────────────────────────────────────────────

// tryAssignToAvailableWorkers scans all idle workers and assigns tasks.
// Caller must hold s.mu.
func (s *taskQueueServer) tryAssignToAvailableWorkers() {
	for _, w := range s.workers {
		if !w.dead && w.currentTaskID == "" {
			s.tryAssignTaskToWorker(w)
		}
	}
}

// tryAssignTaskToWorker picks the best queued task for w and pushes it.
// Caller must hold s.mu.
func (s *taskQueueServer) tryAssignTaskToWorker(w *workerState) {
	if w.dead || w.currentTaskID != "" {
		return
	}

	task := s.dequeueFor(w.workerType)
	if task == nil {
		return
	}

	task.taskStatus = "Processing"
	task.workerID = w.id
	w.currentTaskID = task.id

	log.Printf("[Server] Assigned task %s to worker %s", task.id, w.id)

	// Channel is buffered(1) and worker is idle, so this never blocks.
	select {
	case w.taskChan <- &pb.Task{TaskId: task.id, Type: task.taskType, Payload: task.payload}:
	default:
		// Should never happen – put task back.
		log.Printf("[Server] WARN: taskChan full for %s, re-queuing %s", w.id, task.id)
		task.taskStatus = "Queued"
		task.workerID = ""
		w.currentTaskID = ""
		s.requeueFront(task)
	}
}

// dequeueFor picks and removes the best task from the queues for the given worker type.
// Caller must hold s.mu.
func (s *taskQueueServer) dequeueFor(wt pb.WorkerType) *queuedTask {
	hasCPU := len(s.cpuQueue) > 0
	hasIO := len(s.ioQueue) > 0

	switch wt {
	case pb.WorkerType_WORKER_CPU:
		if hasCPU {
			t := s.cpuQueue[0]
			s.cpuQueue = s.cpuQueue[1:]
			return t
		}
	case pb.WorkerType_WORKER_IO:
		if hasIO {
			t := s.ioQueue[0]
			s.ioQueue = s.ioQueue[1:]
			return t
		}
	case pb.WorkerType_WORKER_BOTH:
		switch {
		case hasCPU && hasIO:
			if s.cpuQueue[0].arrivalTime.Before(s.ioQueue[0].arrivalTime) {
				t := s.cpuQueue[0]
				s.cpuQueue = s.cpuQueue[1:]
				return t
			}
			t := s.ioQueue[0]
			s.ioQueue = s.ioQueue[1:]
			return t
		case hasCPU:
			t := s.cpuQueue[0]
			s.cpuQueue = s.cpuQueue[1:]
			return t
		case hasIO:
			t := s.ioQueue[0]
			s.ioQueue = s.ioQueue[1:]
			return t
		}
	}
	return nil
}

// requeueFront puts a task at the front of its queue. Caller must hold s.mu.
func (s *taskQueueServer) requeueFront(task *queuedTask) {
	if task.taskType == pb.TaskType_CPU {
		s.cpuQueue = append([]*queuedTask{task}, s.cpuQueue...)
	} else {
		s.ioQueue = append([]*queuedTask{task}, s.ioQueue...)
	}
}

// ─── Heartbeat checker ─────────────────────────────────────────────────────

func (s *taskQueueServer) heartbeatChecker() {
	ticker := time.NewTicker(5 * time.Second)
	defer ticker.Stop()

	for range ticker.C {
		s.mu.Lock()
		now := time.Now()

		for _, w := range s.workers {
			if w.dead {
				continue
			}
			if now.Sub(w.lastHeartbeat) > 15*time.Second {
				log.Printf("[Server] Worker %s failed (no heartbeat for >15s) – marking dead", w.id)
				w.dead = true
				close(w.doneChan) // signal RequestTask to close the stream

				if w.currentTaskID != "" {
					task := s.tasks[w.currentTaskID]
					if task != nil {
						log.Printf("[Server] Re-queuing task %s at front of queue", task.id)
						task.taskStatus = "Queued"
						task.workerID = ""
						s.requeueFront(task)
					}
					w.currentTaskID = ""
				}
			}
		}

		s.tryAssignToAvailableWorkers()
		s.mu.Unlock()
	}
}

// ─── Utilities ─────────────────────────────────────────────────────────────

func taskTypeString(t pb.TaskType) string {
	if t == pb.TaskType_CPU {
		return "CPU"
	}
	return "IO"
}

func workerTypeString(t pb.WorkerType) string {
	switch t {
	case pb.WorkerType_WORKER_CPU:
		return "CPU"
	case pb.WorkerType_WORKER_IO:
		return "IO"
	default:
		return "BOTH"
	}
}

// ─── Main ──────────────────────────────────────────────────────────────────

func main() {
	if len(os.Args) < 2 {
		log.Fatal("Usage: server <address>  e.g. localhost:50051")
	}

	addr := os.Args[1]
	lis, err := net.Listen("tcp", addr)
	if err != nil {
		log.Fatalf("Failed to listen on %s: %v", addr, err)
	}

	grpcSrv := grpc.NewServer()
	pb.RegisterTaskQueueServiceServer(grpcSrv, newTaskQueueServer())

	fmt.Printf("[Server] Listening on %s\n", addr)
	if err := grpcSrv.Serve(lis); err != nil {
		log.Fatalf("Failed to serve: %v", err)
	}
}
