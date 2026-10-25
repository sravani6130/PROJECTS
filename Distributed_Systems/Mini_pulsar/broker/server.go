package main

import (
	"bufio"
	"context"
	"fmt"
	"log"
	"net"
	"os"
	"strconv"
	"strings"
	"sync"
	"time"

	"google.golang.org/grpc"
	pb "project/proto/pubsub"
)

type MessageQueue struct {
	messages      []*pb.Message
	offsets       map[string]int64
	mu            sync.RWMutex
	diskPath      string
	maxInMemory   int
	flushInterval time.Duration
	startOffset   int64
	
}
type subscriptionState struct {
	mu              sync.Mutex
	roundRobinIndex int
	activeExclusive string // for exclusive mode
}

type brokerServer struct {
    pb.UnimplementedBrokerServiceServer
    topics     map[string]*MessageQueue
    mu         sync.RWMutex
    isLeader   bool
    brokerId   string
    brokerAddr string
    peers      []string
    dedupMap   map[string]bool
    leaderFile string
	subscriptions map[string][]string // subscriptionId -> list of consumerIds
	subscriptionStates map[string]*subscriptionState // NEW: subscriptionId -> state


}


func (b *brokerServer) Heartbeat(ctx context.Context, req *pb.HeartbeatRequest) (*pb.HeartbeatResponse, error) {
	return &pb.HeartbeatResponse{Alive: true}, nil
}

func (b *brokerServer) Replicate(ctx context.Context, req *pb.ReplicateRequest) (*pb.ReplicateResponse, error) {
	b.mu.Lock()
	queue, exists := b.topics[req.Topic]
	if !exists {
		queue = &MessageQueue{
			messages:      []*pb.Message{},
			offsets:       make(map[string]int64),
			diskPath:      fmt.Sprintf("%s.txt", req.Topic),
			maxInMemory:   10,
			flushInterval: 5 * time.Second,
		}
		queue.loadFromDisk()
		b.topics[req.Topic] = queue
	}
	b.mu.Unlock()

	queue.mu.Lock()
	msg := &pb.Message{
		Id:     req.Id,
		Topic:  req.Topic,
		Data:   req.Message,
		Offset: req.Offset,
	}
	queue.messages = append(queue.messages, msg)
	queue.mu.Unlock()

	log.Printf("[Replication] Message replicated: %s [offset %d]", req.Message, req.Offset)
	return &pb.ReplicateResponse{Success: true}, nil
}
func (mq *MessageQueue) flushToDisk() {
	mq.mu.Lock()
	defer mq.mu.Unlock()
	if len(mq.messages) <= mq.maxInMemory {
		return
	}
	flushCount := len(mq.messages) - mq.maxInMemory
	toFlush := mq.messages[:flushCount]
	mq.messages = mq.messages[flushCount:]
	mq.startOffset += int64(flushCount)
	f, err := os.OpenFile(mq.diskPath, os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0644)
	if err != nil {
		log.Printf("Failed to open flush file: %v", err)
		return
	}
	defer f.Close()
	for _, msg := range toFlush {
		line := fmt.Sprintf("%s|%s|%s|%d\n", msg.Id, msg.Topic, msg.Data, msg.Offset)
		_, err := f.WriteString(line)
		if err != nil {
			log.Printf("Failed to write to disk: %v", err)
		}
	}
	log.Printf("Flushed %d messages to disk (%s)", flushCount, mq.diskPath)
}

func (mq *MessageQueue) loadFromDisk() {
	f, err := os.Open(mq.diskPath)
	if err != nil {
		return
	}
	defer f.Close()
	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		line := scanner.Text()
		parts := strings.Split(line, "|")
		if len(parts) != 4 {
			continue
		}
		offset, _ := strconv.ParseInt(parts[3], 10, 64)
		msg := &pb.Message{
			Id:     parts[0],
			Topic:  parts[1],
			Data:   parts[2],
			Offset: offset,
		}
		mq.messages = append(mq.messages, msg)
	}
	if len(mq.messages) > 0 {
		mq.startOffset = mq.messages[0].Offset
	}
}

func newBroker(isLeader bool, brokerId, brokerAddr string, peers []string, leaderFile string) *brokerServer {
    return &brokerServer{
        topics:     make(map[string]*MessageQueue),
        isLeader:   isLeader,
        brokerId:   brokerId,
        brokerAddr: brokerAddr,
        peers:      peers,
        dedupMap:   make(map[string]bool),
        leaderFile: leaderFile,
		subscriptions: make(map[string][]string),
		subscriptionStates: make(map[string]*subscriptionState),


    }
}
func (b *brokerServer) promoteToLeader() {
	b.mu.Lock()
	defer b.mu.Unlock()
	b.isLeader = true
	_ = os.WriteFile(b.leaderFile, []byte(b.brokerAddr), 0644) // write address
	log.Printf("[Failover] %s is now the LEADER", b.brokerId)
}



func (b *brokerServer) monitorLeader() {
	go func() {
		for {
			time.Sleep(3 * time.Second)

			if b.isLeader {
				_ = os.WriteFile(b.leaderFile, []byte(b.brokerAddr), 0644) // write address
				continue
			}

			data, err := os.ReadFile(b.leaderFile)
			leaderAddr := strings.TrimSpace(string(data))

			if err != nil || leaderAddr == "" {
				log.Println("[Failover] No leader info. Promoting self...")
				b.promoteToLeader()
				continue
			}

			conn, err := grpc.Dial(leaderAddr, grpc.WithInsecure())
			if err != nil {
				log.Printf("[Failover] Could not connect to leader %s: %v", leaderAddr, err)
				b.promoteToLeader()
				continue
			}

			client := pb.NewBrokerServiceClient(conn)
			ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
			_, err = client.Heartbeat(ctx, &pb.HeartbeatRequest{BrokerId: b.brokerId})
			cancel()
			conn.Close()

			if err != nil {
				log.Printf("[Failover] Leader %s not responding. Promoting self...", leaderAddr)
				b.promoteToLeader()
			}
		}
	}()
}


func (b *brokerServer) Publish(ctx context.Context, req *pb.PublishRequest) (*pb.PublishResponse, error) {
	if !b.isLeader {
		return &pb.PublishResponse{Success: false}, fmt.Errorf("this broker is not the leader")
	}
	b.mu.Lock()
	queue, exists := b.topics[req.Topic]
	if !exists {
		queue = &MessageQueue{
			messages:      []*pb.Message{},
			offsets:       make(map[string]int64),
			diskPath:      fmt.Sprintf("%s.txt", req.Topic),
			maxInMemory:   10,
			flushInterval: 5 * time.Second,
		}
		queue.loadFromDisk()
		b.topics[req.Topic] = queue
		go func(q *MessageQueue) {
			ticker := time.NewTicker(q.flushInterval)
			for range ticker.C {
				q.flushToDisk()
			}
		}(queue)
	}
	b.mu.Unlock()

	if b.dedupMap[req.Message] {
		log.Printf("Duplicate message detected: %s", req.Message)
		return &pb.PublishResponse{Success: false}, nil
	}
	b.dedupMap[req.Message] = true

	log.Printf("Topic '%s' published with message: '%s'", req.Topic, req.Message)

	queue.mu.Lock()
	msg := &pb.Message{
		Id:     fmt.Sprintf("msg-%d", queue.startOffset+int64(len(queue.messages))),
		Topic:  req.Topic,
		Data:   req.Message,
		Offset: queue.startOffset + int64(len(queue.messages)),
	}
	queue.messages = append(queue.messages, msg)
	queue.mu.Unlock()

	for _, peer := range b.peers {
		go func(p string) {
			conn, err := grpc.Dial(p, grpc.WithInsecure())
			if err != nil {
				log.Printf("[Replication] Failed to connect to %s: %v", p, err)
				return
			}
			defer conn.Close()
			client := pb.NewBrokerServiceClient(conn)
			_, err = client.Replicate(context.Background(), &pb.ReplicateRequest{
				Id:      msg.Id,
				Topic:   msg.Topic,
				Message: msg.Data,
				Offset:  msg.Offset,
			})
			if err != nil {
				log.Printf("[Replication] Failed to replicate to %s: %v", p, err)
			}
		}(peer)
	}

	return &pb.PublishResponse{Success: true}, nil
}

func (b *brokerServer) Subscribe(req *pb.SubscribeRequest, stream pb.BrokerService_SubscribeServer) error {
	log.Printf("[Subscribe] Consumer '%s' subscribed to topic '%s' with subscriptionId '%s' in %s mode from offset %d",
		req.ConsumerId, req.Topic, req.SubscriptionId, req.Mode, req.Offset)

	// Setup topic & subscription
	b.mu.Lock()
	queue, exists := b.topics[req.Topic]
	if !exists {
		b.mu.Unlock()
		return fmt.Errorf("topic %s not found", req.Topic)
	}

	// Ensure subscription state exists
	if _, ok := b.subscriptionStates[req.SubscriptionId]; !ok {
		b.subscriptionStates[req.SubscriptionId] = &subscriptionState{}
	}

	// Handle subscription modes
	state := b.subscriptionStates[req.SubscriptionId]

	switch req.Mode {
	case "Exclusive":
		state.mu.Lock()
		if state.activeExclusive != "" && state.activeExclusive != req.ConsumerId {
			state.mu.Unlock()
			b.mu.Unlock()
			return fmt.Errorf("exclusive subscription already in use by %s", state.activeExclusive)
		}
		state.activeExclusive = req.ConsumerId
		state.mu.Unlock()

	case "Shared", "Failover":
		b.subscriptions[req.SubscriptionId] = append(b.subscriptions[req.SubscriptionId], req.ConsumerId)
	}
	b.mu.Unlock()

	queue.mu.Lock()
	queue.offsets[req.ConsumerId] = req.Offset
	queue.mu.Unlock()

	for {
		queue.mu.RLock()
		offset := queue.offsets[req.ConsumerId]
		start := queue.startOffset
		end := start + int64(len(queue.messages))
		queue.mu.RUnlock()

		if offset < start {
			time.Sleep(100 * time.Millisecond)
			continue
		}

		if offset < end {
			msg := queue.messages[offset-start]

			// Mode: Shared (Round-robin)
			if req.Mode == "Shared" {
				b.mu.RLock()
				consumers := b.subscriptions[req.SubscriptionId]
				state := b.subscriptionStates[req.SubscriptionId]
				b.mu.RUnlock()

				state.mu.Lock()
				current := consumers[state.roundRobinIndex%len(consumers)]
				if current != req.ConsumerId {
					state.mu.Unlock()
					time.Sleep(50 * time.Millisecond)
					continue
				}
				state.roundRobinIndex++
				state.mu.Unlock()
			}

			// Mode: Failover
			if req.Mode == "Failover" {
				b.mu.RLock()
				if len(b.subscriptions[req.SubscriptionId]) == 0 || b.subscriptions[req.SubscriptionId][0] != req.ConsumerId {
					b.mu.RUnlock()
					time.Sleep(300 * time.Millisecond)
					continue
				}
				b.mu.RUnlock()
			}

			// Simulate backpressure
			if req.IsSlow && msg.Offset%5 == 0 {
				log.Printf("[Backpressure] Simulating delay for %s", req.ConsumerId)
				time.Sleep(2 * time.Second)
			}

			if err := stream.Send(msg); err != nil {
				log.Printf("Send error to %s: %v", req.ConsumerId, err)

				// Cleanup exclusive on disconnect
				if req.Mode == "Exclusive" {
					state.mu.Lock()
					if state.activeExclusive == req.ConsumerId {
						state.activeExclusive = ""
					}
					state.mu.Unlock()
				}

				return err
			}

			log.Printf("[Deliver] Message %s sent to %s [%s]", msg.Id, req.ConsumerId, req.Mode)

			queue.mu.Lock()
			queue.offsets[req.ConsumerId]++
			queue.mu.Unlock()
		} else {
			time.Sleep(100 * time.Millisecond)
		}
	}
}




func (b *brokerServer) Acknowledge(ctx context.Context, req *pb.AckRequest) (*pb.AckResponse, error) {
	b.mu.RLock()
	queue, exists := b.topics[req.Topic]
	b.mu.RUnlock()
	if !exists {
		return &pb.AckResponse{Success: false}, fmt.Errorf("topic %s not found", req.Topic)
	}
	queue.mu.Lock()
	queue.offsets[req.ConsumerId] = req.Offset + 1
	queue.mu.Unlock()
	log.Printf("Ack from %s for message %s (offset %d)", req.ConsumerId, req.MessageId, req.Offset)
	return &pb.AckResponse{Success: true}, nil
}

func main() {
	isLeader := os.Getenv("ROLE") == "leader"
	brokerId := os.Getenv("BROKER_ID")
	port := os.Getenv("PORT")
	if port == "" {
		port = "50051"
	}
	brokerAddr := "localhost:" + port

	peersEnv := os.Getenv("PEERS") // comma-separated list like "localhost:50052,localhost:50053"
	peers := strings.Split(peersEnv, ",")
	leaderFile := "leader.txt"

	lis, err := net.Listen("tcp", ":"+port) // <- FIXED HERE
	if err != nil {
		log.Fatalf("Failed to listen: %v", err)
	}

	grpcServer := grpc.NewServer()
	broker := newBroker(isLeader, brokerId, brokerAddr, peers, leaderFile)
	pb.RegisterBrokerServiceServer(grpcServer, broker)
	broker.monitorLeader()

	log.Printf("Broker %s (%s) running at :%s", brokerId, map[bool]string{true: "Leader", false: "Follower"}[isLeader], port)
	grpcServer.Serve(lis)
}

