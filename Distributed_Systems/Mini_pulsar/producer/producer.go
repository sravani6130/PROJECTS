package main

import (
	"context"
	"encoding/csv"
	"fmt"
	"log"
	"os"
	"strings"
	"time"

	pb "project/proto/pubsub"

	"google.golang.org/grpc"
)

func getLeaderAddress() string {
	data, err := os.ReadFile("../broker/leader.txt")
	if err != nil {
		log.Printf("Could not read leader.txt, using default localhost:50051")
		return "localhost:50051"
	}
	return strings.TrimSpace(string(data))
}

func connectToLeader() (pb.BrokerServiceClient, *grpc.ClientConn, string, error) {
	addr := getLeaderAddress()
	conn, err := grpc.Dial(addr, grpc.WithInsecure())
	if err != nil {
		return nil, nil, addr, err
	}
	client := pb.NewBrokerServiceClient(conn)
	return client, conn, addr, nil
}

func main() {
	topic := "demo"
	totalMessages := 10
	logFile := "producer_log.csv"

	// Prepare CSV file for logging
	f, err := os.Create(logFile)
	if err != nil {
		log.Fatalf("Could not create log file: %v", err)
	}
	defer f.Close()

	writer := csv.NewWriter(f)
	defer writer.Flush()
	writer.Write([]string{"message_id", "send_time_utc"})

	for i := 0; i < totalMessages; i++ {
		for {
			client, conn, addr, err := connectToLeader()
			if err != nil {
				log.Printf("Connection to leader (%s) failed: %v. Retrying...", addr, err)
				time.Sleep(2 * time.Second)
				continue
			}

			// Embed timestamp in message for latency tracking
			sendTime := time.Now().UTC().Format(time.RFC3339Nano)
			msg := fmt.Sprintf("msg-%d|%s", i, sendTime)

			req := &pb.PublishRequest{
				Topic:   topic,
				Message: msg,
			}

			ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
			resp, err := client.Publish(ctx, req)
			cancel()
			conn.Close()

			if err != nil {
				log.Printf("Publish failed to %s: %v. Retrying...", addr, err)
				time.Sleep(2 * time.Second)
				continue
			}

			if resp.Success {
				log.Printf("Published message %d at %s", i, sendTime)
				writer.Write([]string{fmt.Sprintf("msg-%d", i), sendTime})
			} else {
				log.Printf("Broker %s rejected message %d. Retrying...", addr, i)
				time.Sleep(2 * time.Second)
				continue
			}

			break // message successfully sent
		}

		time.Sleep(10 * time.Millisecond) // adjustable rate for throughput test
	}

	log.Println("✅ Producer finished sending messages")
}
