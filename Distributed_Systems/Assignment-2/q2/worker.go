package main

import (
	"context"
	"fmt"
	"io"
	"log"
	"math/rand"
	"os"
	"strconv"
	"strings"
	"time"

	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"

	pb "task_queue_system/taskqueue"
)

// ─── Task simulation ───────────────────────────────────────────────────────

// simulateCPU performs an N×N matrix multiplication to create realistic CPU load.
func simulateCPU(payload string) error {
	n, err := strconv.Atoi(strings.TrimSpace(payload))
	if err != nil || n <= 0 {
		return fmt.Errorf("invalid CPU payload %q: %v", payload, err)
	}

	log.Printf("[Worker] Starting %dx%d matrix multiplication", n, n)

	// Allocate and fill two N×N matrices with random values.
	a := make([][]float64, n)
	b := make([][]float64, n)
	c := make([][]float64, n)
	for i := 0; i < n; i++ {
		a[i] = make([]float64, n)
		b[i] = make([]float64, n)
		c[i] = make([]float64, n)
		for j := 0; j < n; j++ {
			a[i][j] = rand.Float64()
			b[i][j] = rand.Float64()
		}
	}

	// Naive O(n³) multiplication.
	for i := 0; i < n; i++ {
		for k := 0; k < n; k++ {
			for j := 0; j < n; j++ {
				c[i][j] += a[i][k] * b[k][j]
			}
		}
	}

	log.Printf("[Worker] Matrix multiplication complete (result[0][0]=%.4f)", c[0][0])
	return nil
}

// simulateIO sleeps for the duration given in the payload (seconds).
func simulateIO(payload string) error {
	secs, err := strconv.Atoi(strings.TrimSpace(payload))
	if err != nil || secs < 0 {
		return fmt.Errorf("invalid IO payload %q: %v", payload, err)
	}

	log.Printf("[Worker] Sleeping for %d second(s) (IO simulation)", secs)
	time.Sleep(time.Duration(secs) * time.Second)
	log.Printf("[Worker] IO sleep complete")
	return nil
}

// ─── Worker ────────────────────────────────────────────────────────────────

type worker struct {
	id         string
	workerType pb.WorkerType
	client     pb.TaskQueueServiceClient
	conn       *grpc.ClientConn
}

func newWorker(addr string, wtype pb.WorkerType) (*worker, error) {
	conn, err := grpc.Dial(addr, grpc.WithTransportCredentials(insecure.NewCredentials()))
	if err != nil {
		return nil, fmt.Errorf("failed to connect to %s: %v", addr, err)
	}

	client := pb.NewTaskQueueServiceClient(conn)

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	resp, err := client.RegisterWorker(ctx, &pb.WorkerConfig{Type: wtype})
	cancel()
	if err != nil {
		conn.Close()
		return nil, fmt.Errorf("RegisterWorker failed: %v", err)
	}

	w := &worker{
		id:         resp.WorkerId,
		workerType: wtype,
		client:     client,
		conn:       conn,
	}

	log.Printf("[Worker] Registered with ID: %s (type: %s)", w.id, workerTypeName(wtype))
	return w, nil
}

func (w *worker) close() {
	w.conn.Close()
}

// sendHeartbeats sends a heartbeat every 5 seconds until ctx is cancelled.
func (w *worker) sendHeartbeats(ctx context.Context) {
	ticker := time.NewTicker(5 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			hbCtx, cancel := context.WithTimeout(ctx, 3*time.Second)
			_, err := w.client.SendHeartbeat(hbCtx, &pb.Heartbeat{
				WorkerId:  w.id,
				Timestamp: time.Now().UnixMilli(),
			})
			cancel()
			if err != nil {
				log.Printf("[Worker %s] Heartbeat error: %v", w.id, err)
			}
		}
	}
}

// run opens the task stream and processes tasks until the stream closes.
func (w *worker) run(ctx context.Context) {
	log.Printf("[Worker %s] Waiting for tasks...", w.id)

	stream, err := w.client.RequestTask(ctx, &pb.WorkerId{WorkerId: w.id})
	if err != nil {
		log.Printf("[Worker %s] RequestTask error: %v", w.id, err)
		return
	}

	for {
		task, err := stream.Recv()
		if err == io.EOF {
			log.Printf("[Worker %s] Stream closed by server (EOF)", w.id)
			return
		}
		if err != nil {
			log.Printf("[Worker %s] Stream error: %v", w.id, err)
			return
		}

		w.processTask(ctx, task)
	}
}

// processTask executes a single task and reports its result.
func (w *worker) processTask(ctx context.Context, task *pb.Task) {
	typeStr := "CPU"
	if task.Type == pb.TaskType_IO {
		typeStr = "IO"
	}
	log.Printf("[Worker %s] Received task %s (%s, payload=%s)", w.id, task.TaskId, typeStr, task.Payload)

	// Notify server that processing has started.
	w.updateStatus(ctx, task.TaskId, "Processing")

	var simErr error
	switch task.Type {
	case pb.TaskType_CPU:
		simErr = simulateCPU(task.Payload)
	case pb.TaskType_IO:
		simErr = simulateIO(task.Payload)
	}

	finalStatus := "Completed"
	if simErr != nil {
		log.Printf("[Worker %s] Task %s failed: %v", w.id, task.TaskId, simErr)
		finalStatus = "Failed"
	}

	w.updateStatus(ctx, task.TaskId, finalStatus)
	log.Printf("[Worker %s] Task %s %s. Waiting for next task...", w.id, task.TaskId, finalStatus)
}

func (w *worker) updateStatus(ctx context.Context, taskID, newStatus string) {
	updCtx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()

	_, err := w.client.UpdateTaskStatus(updCtx, &pb.TaskStatusUpdate{
		TaskId:   taskID,
		WorkerId: w.id,
		Status:   newStatus,
	})
	if err != nil {
		log.Printf("[Worker %s] UpdateTaskStatus(%s→%s) error: %v", w.id, taskID, newStatus, err)
	}
}

// ─── Utilities ─────────────────────────────────────────────────────────────

func workerTypeName(t pb.WorkerType) string {
	switch t {
	case pb.WorkerType_WORKER_CPU:
		return "CPU"
	case pb.WorkerType_WORKER_IO:
		return "IO"
	default:
		return "BOTH"
	}
}

func parseWorkerType(s string) (pb.WorkerType, error) {
	switch strings.ToUpper(strings.TrimSpace(s)) {
	case "CPU":
		return pb.WorkerType_WORKER_CPU, nil
	case "IO":
		return pb.WorkerType_WORKER_IO, nil
	case "BOTH":
		return pb.WorkerType_WORKER_BOTH, nil
	default:
		return 0, fmt.Errorf("unknown worker type %q (use CPU, IO, or BOTH)", s)
	}
}

// ─── Main ──────────────────────────────────────────────────────────────────

func main() {
	if len(os.Args) < 3 {
		log.Fatal("Usage: worker <server-address> <CPU|IO|BOTH>")
	}

	addr := os.Args[1]
	wtype, err := parseWorkerType(os.Args[2])
	if err != nil {
		log.Fatalf("Invalid worker type: %v", err)
	}

	w, err := newWorker(addr, wtype)
	if err != nil {
		log.Fatalf("Failed to create worker: %v", err)
	}
	defer w.close()

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Send heartbeats in the background.
	go w.sendHeartbeats(ctx)

	// Block here processing tasks until the stream ends.
	w.run(ctx)
}
