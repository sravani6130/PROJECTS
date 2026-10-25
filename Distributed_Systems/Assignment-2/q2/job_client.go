package main

import (
	"bufio"
	"context"
	"fmt"
	"log"
	"os"
	"strings"
	"time"

	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"

	pb "task_queue_system/taskqueue"
)

const pollInterval = 2 * time.Second

// ─── Client ────────────────────────────────────────────────────────────────

type jobClient struct {
	addr   string
	conn   *grpc.ClientConn
	client pb.TaskQueueServiceClient
}

func newJobClient(addr string) (*jobClient, error) {
	conn, err := grpc.Dial(addr, grpc.WithTransportCredentials(insecure.NewCredentials()))
	if err != nil {
		return nil, fmt.Errorf("failed to connect to %s: %v", addr, err)
	}
	return &jobClient{
		addr:   addr,
		conn:   conn,
		client: pb.NewTaskQueueServiceClient(conn),
	}, nil
}

func (jc *jobClient) close() { jc.conn.Close() }

// submitTask submits a task and returns its ID.
func (jc *jobClient) submitTask(taskType pb.TaskType, payload string) (string, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	resp, err := jc.client.SubmitTask(ctx, &pb.TaskRequest{Type: taskType, Payload: payload})
	if err != nil {
		return "", err
	}
	return resp.TaskId, nil
}

// getStatus returns the current status response for a task.
func (jc *jobClient) getStatus(taskID string) (*pb.TaskStatusResponse, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	return jc.client.GetTaskStatus(ctx, &pb.TaskStatusRequest{TaskId: taskID})
}

// pollStatus polls GetTaskStatus every pollInterval and prints whenever the
// status changes. It stops when the task reaches a terminal state.
func (jc *jobClient) pollStatus(taskID string) {
	lastStatus := ""
	for {
		resp, err := jc.getStatus(taskID)
		if err != nil {
			log.Printf("[Client] Error polling task %s: %v", taskID, err)
			time.Sleep(pollInterval)
			continue
		}

		if resp.Status != lastStatus {
			if resp.WorkerId != "" {
				fmt.Printf("[Client] Task %s: %s (Worker %s)\n", taskID, resp.Status, resp.WorkerId)
			} else {
				fmt.Printf("[Client] Task %s: %s\n", taskID, resp.Status)
			}
			lastStatus = resp.Status
		}

		if resp.Status == "Completed" || resp.Status == "Failed" {
			return
		}

		time.Sleep(pollInterval)
	}
}

// ─── CLI ───────────────────────────────────────────────────────────────────

func printHelp() {
	fmt.Println("Commands:")
	fmt.Println("  submit CPU <payload>   Submit a CPU task (payload = matrix dimension N)")
	fmt.Println("  submit IO  <payload>   Submit an IO task  (payload = sleep seconds)")
	fmt.Println("  status <task-id>       Query the current status of a task")
	fmt.Println("  help                   Show this message")
	fmt.Println("  quit / exit            Exit the client")
}

func main() {
	if len(os.Args) < 2 {
		log.Fatal("Usage: job_client <server-address>  e.g. localhost:50051")
	}

	addr := os.Args[1]
	jc, err := newJobClient(addr)
	if err != nil {
		log.Fatalf("Failed to create client: %v", err)
	}
	defer jc.close()

	fmt.Printf("[Client] Connected to %s\n", addr)
	printHelp()

	scanner := bufio.NewScanner(os.Stdin)

	for {
		fmt.Print("> ")
		if !scanner.Scan() {
			break
		}
		line := strings.TrimSpace(scanner.Text())
		if line == "" {
			continue
		}

		parts := strings.Fields(line)
		cmd := strings.ToLower(parts[0])

		switch cmd {
		case "submit":
			if len(parts) < 3 {
				fmt.Println("Usage: submit <CPU|IO> <payload>")
				continue
			}
			typeStr := strings.ToUpper(parts[1])
			payload := strings.Join(parts[2:], " ")

			var taskType pb.TaskType
			switch typeStr {
			case "CPU":
				taskType = pb.TaskType_CPU
			case "IO":
				taskType = pb.TaskType_IO
			default:
				fmt.Printf("Unknown task type %q – use CPU or IO\n", typeStr)
				continue
			}

			taskID, err := jc.submitTask(taskType, payload)
			if err != nil {
				fmt.Printf("[Client] Submit failed: %v\n", err)
				continue
			}

			fmt.Printf("[Client] Task submitted. ID: %s (%s, payload=%s)\n", taskID, typeStr, payload)

			// Start background status poller; prints to terminal on each change.
			go jc.pollStatus(taskID)

		case "status":
			if len(parts) < 2 {
				fmt.Println("Usage: status <task-id>")
				continue
			}
			taskID := parts[1]
			resp, err := jc.getStatus(taskID)
			if err != nil {
				fmt.Printf("[Client] Status error: %v\n", err)
				continue
			}
			if resp.WorkerId != "" {
				fmt.Printf("[Client] Task %s: %s (Worker %s)\n", taskID, resp.Status, resp.WorkerId)
			} else {
				fmt.Printf("[Client] Task %s: %s\n", taskID, resp.Status)
			}

		case "help":
			printHelp()

		case "quit", "exit":
			fmt.Println("[Client] Exiting...")
			return

		default:
			fmt.Printf("Unknown command %q. Type 'help' for available commands.\n", cmd)
		}
	}
}
