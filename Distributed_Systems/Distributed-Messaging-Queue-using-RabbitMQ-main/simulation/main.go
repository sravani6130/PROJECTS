package main

import (
	"context"
	"fmt"
	"log"
	"math/rand"
	"time"

	pb "distributed-broker/proto"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
)

func main() {
	producers := []string{"localhost:50051", "localhost:50052"}
	taskTypes := []string{"A", "B", "AB", "TOPIC", "HEADER_A", "HEADER_B"}
	routingKeys := map[string][]string{
		"TOPIC": {"task.A.urgent", "task.B.normal", "task.all.broadcast"},
	}

	fmt.Println("Starting performance simulation...")
	fmt.Printf("Targeting producers: %v\n", producers)

	// Send 60 tasks in total (10 per second for 6 seconds)
	for i := 0; i < 60; i++ {
		taskType := taskTypes[rand.Intn(len(taskTypes))]
		producerAddr := producers[rand.Intn(len(producers))]
		
		routingKey := ""
		if rks, ok := routingKeys[taskType]; ok {
			routingKey = rks[rand.Intn(len(rks))]
		}

		duration := rand.Intn(3) + 1 // 1 to 3 seconds

		go func(i int, addr, tType, rKey string, dur int) {
			conn, err := grpc.Dial(addr, grpc.WithTransportCredentials(insecure.NewCredentials()))
			if err != nil {
				log.Printf("[%d] ERROR: Could not connect to %s: %v", i, addr, err)
				return
			}
			defer conn.Close()

			client := pb.NewTaskServiceClient(conn)
			ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
			defer cancel()

			log.Printf("[%d] Sending %s task to %s...", i, tType, addr)
			_, err = client.SubmitTask(ctx, &pb.TaskRequest{
				TaskType:   tType,
				Duration:   int32(dur),
				RoutingKey: rKey,
			})
			if err != nil {
				log.Printf("[%d] ERROR: SubmitTask failed: %v", i, err)
			}
		}(i, producerAddr, taskType, routingKey, duration)

		time.Sleep(100 * time.Millisecond)
	}

	fmt.Println("Simulation burst complete. Waiting for tasks to finish...")
	time.Sleep(15 * time.Second)
	fmt.Println("Simulation finished.")
}
