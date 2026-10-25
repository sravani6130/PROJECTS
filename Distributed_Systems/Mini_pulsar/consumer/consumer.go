package main

import (
	"context"
	"encoding/csv"
	"fmt"
	"log"
	"os"
	"strconv"
	"strings"
	"sync"
	"time"

	pb "project/proto/pubsub"
	"google.golang.org/grpc"
)

const (
	consumerId      = "consumer-1"
	isSlowConsumer  = false
	offsetDir       = "offsets"
	latencyLogDir   = "latency_logs"
)

var topicConfigs = map[string]struct {
	SubscriptionID string
	Mode           string
}{
	"demo":   {"sub-demo", "Shared"},
	//"orders": {"sub-orders", "Shared"},
	//"logs":   {"sub-logs", "Failover"},
}

var mu sync.Mutex

func loadOffset(topic, subID string) int64 {
	path := fmt.Sprintf("%s/offset_%s_%s_%s.txt", offsetDir, consumerId, subID, topic)
	data, err := os.ReadFile(path)
	if err != nil {
		return 0
	}
	offset, err := strconv.ParseInt(string(data), 10, 64)
	if err != nil {
		return 0
	}
	return offset
}

func saveOffset(topic, subID string, offset int64) {
	mu.Lock()
	defer mu.Unlock()
	_ = os.MkdirAll(offsetDir, 0755)
	path := fmt.Sprintf("%s/offset_%s_%s_%s.txt", offsetDir, consumerId, subID, topic)
	_ = os.WriteFile(path, []byte(strconv.FormatInt(offset, 10)), 0644)
}

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

func parseMessage(msg string) (string, time.Time, error) {
	parts := strings.Split(msg, "|")
	if len(parts) != 2 {
		return "", time.Time{}, fmt.Errorf("invalid message format")
	}
	sendTime, err := time.Parse(time.RFC3339Nano, parts[1])
	if err != nil {
		return "", time.Time{}, err
	}
	return parts[0], sendTime, nil
}

func logLatency(topic string, messageID string, latency time.Duration) {
	_ = os.MkdirAll(latencyLogDir, 0755)
	path := fmt.Sprintf("%s/latency_log_%s.csv", latencyLogDir, topic)

	f, err := os.OpenFile(path, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0644)
	if err != nil {
		log.Printf("[%s] Failed to log latency: %v", topic, err)
		return
	}
	defer f.Close()

	writer := csv.NewWriter(f)
	defer writer.Flush()

	writer.Write([]string{
		messageID,
		time.Now().UTC().Format(time.RFC3339Nano),
		latency.String(),
	})
}

func subscribeToTopic(topic, subID, mode string) {
	lastOffset := loadOffset(topic, subID)

	for {
		client, conn, addr, err := connectToLeader()
		if err != nil {
			log.Printf("[%s] Failed to connect to leader %s: %v. Retrying...", topic, addr, err)
			time.Sleep(2 * time.Second)
			continue
		}

		stream, err := client.Subscribe(context.Background(), &pb.SubscribeRequest{
			Topic:           topic,
			ConsumerId:      consumerId,
			SubscriptionId:  subID,
			Offset:          lastOffset,
			Mode:            mode,
			IsSlow:          isSlowConsumer,
		})
		if err != nil {
			log.Printf("[%s] Subscribe failed: %v. Retrying...", topic, err)
			conn.Close()
			time.Sleep(2 * time.Second)
			continue
		}

		log.Printf("[%s] Subscribed as %s [%s] via %s", topic, consumerId, mode, addr)

		for {
			msg, err := stream.Recv()
			if err != nil {
				log.Printf("[%s] Stream closed: %v. Reconnecting...", topic, err)
				conn.Close()
				time.Sleep(2 * time.Second)
				break
			}

			log.Printf("[%s] Received: %s [Offset: %d]", topic, msg.Data, msg.Offset)

			msgID, sendTime, err := parseMessage(msg.Data)
			if err == nil {
				latency := time.Since(sendTime)
				log.Printf("[%s] Latency for %s: %s", topic, msgID, latency)
				logLatency(topic, msgID, latency)
			} else {
				log.Printf("[%s] Failed to parse timestamp: %v", topic, err)
			}

			_, err = client.Acknowledge(context.Background(), &pb.AckRequest{
				MessageId:  msg.Id,
				ConsumerId: consumerId,
				Topic:      topic,
				Offset:     msg.Offset,
				AckType:    "at-least-once",
			})
			if err != nil {
				log.Printf("[%s] Ack failed: %v", topic, err)
			}

			saveOffset(topic, subID, msg.Offset+1)
			lastOffset = msg.Offset + 1
		}
	}
}

func main() {
	for topic, config := range topicConfigs {
		go subscribeToTopic(topic, config.SubscriptionID, config.Mode)
	}
	select {}
}
