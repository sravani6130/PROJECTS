package main

import (
	"context"
	"flag"
	"fmt"
	"log"
	"net"
	"os"
	"time"

	pb "distributed-broker/proto"
	"github.com/joho/godotenv"
	amqp "github.com/rabbitmq/amqp091-go"
	"google.golang.org/grpc"
)

const (
	DirectExchange = "task_direct_exchange"
	FanoutExchange = "task_fanout_exchange"
	TopicExchange  = "task_topic_exchange"
	HeaderExchange = "task_header_exchange"
	DLXExchange    = "task_dlx_exchange"
)



// server holds our gRPC service implementation.
// In Python terms, this is like a class with self.amqpChannel as an instance variable.
type server struct {
	pb.UnimplementedTaskServiceServer
	amqpChannel *amqp.Channel
}

// SubmitTask is called by the client via gRPC. It routes the task to the correct
// RabbitMQ exchange based on the task_type field.
func (s *server) SubmitTask(ctx context.Context, in *pb.TaskRequest) (*pb.TaskResponse, error) {
	taskID := fmt.Sprintf("task-%d", time.Now().UnixNano())
	log.Printf("[METRIC] PRODUCER_RECEIVE: task_id=%s, type=%q, duration=%ds, routing_key=%q, timestamp=%s",
		taskID, in.GetTaskType(), in.GetDuration(), in.GetRoutingKey(), time.Now().Format(time.RFC3339Nano))

	// The message body now contains taskID and duration
	body := []byte(fmt.Sprintf("%s|%d", taskID, in.GetDuration()))

	// Helper to publish a single message to a given exchange + routing key.
	publish := func(exchange, routingKey string) error {
		log.Printf("[METRIC] PRODUCER_SEND: task_id=%s, exchange=%s, routing_key=%s, timestamp=%s",
			taskID, exchange, routingKey, time.Now().Format(time.RFC3339Nano))
		return s.amqpChannel.PublishWithContext(ctx,
			exchange,
			routingKey,
			false,
			false,
			amqp.Publishing{
				DeliveryMode: amqp.Persistent,
				ContentType:  "text/plain",
				Body:         body,
			},
		)
	}

	// Helper to publish with headers
	publishWithHeaders := func(exchange, routingKey string, headers amqp.Table) error {
		log.Printf("[METRIC] PRODUCER_SEND: task_id=%s, exchange=%s, headers=%v, timestamp=%s",
			taskID, exchange, headers, time.Now().Format(time.RFC3339Nano))
		return s.amqpChannel.PublishWithContext(ctx,
			exchange,
			routingKey,
			false,
			false,
			amqp.Publishing{
				DeliveryMode: amqp.Persistent,
				ContentType:  "text/plain",
				Body:         body,
				Headers:      headers,
			},
		)
	}

	switch in.GetTaskType() {
	case "A":
		if err := publish(DirectExchange, "A"); err != nil {
			return &pb.TaskResponse{Success: false, Message: fmt.Sprintf("Direct publish failed: %v", err)}, err
		}
	case "B":
		if err := publish(DirectExchange, "B"); err != nil {
			return &pb.TaskResponse{Success: false, Message: fmt.Sprintf("Direct publish failed: %v", err)}, err
		}
	case "AB":
		if err := publish(FanoutExchange, ""); err != nil {
			return &pb.TaskResponse{Success: false, Message: fmt.Sprintf("Fanout publish failed: %v", err)}, err
		}
	case "TOPIC":
		routingKey := in.GetRoutingKey()
		if routingKey == "" {
			routingKey = "task.A.normal"
		}
		if err := publish(TopicExchange, routingKey); err != nil {
			return &pb.TaskResponse{Success: false, Message: fmt.Sprintf("Topic publish failed: %v", err)}, err
		}
	case "HEADER_A":
		headers := amqp.Table{"type": "A"}
		if err := publishWithHeaders(HeaderExchange, "", headers); err != nil {
			return &pb.TaskResponse{Success: false, Message: fmt.Sprintf("Header A publish failed: %v", err)}, err
		}
	case "HEADER_B":
		headers := amqp.Table{"type": "B"}
		if err := publishWithHeaders(HeaderExchange, "", headers); err != nil {
			return &pb.TaskResponse{Success: false, Message: fmt.Sprintf("Header B publish failed: %v", err)}, err
		}
	default:
		msg := fmt.Sprintf("Unknown task type %q. Use: A, B, AB, or TOPIC", in.GetTaskType())
		return &pb.TaskResponse{Success: false, Message: msg}, nil
	}

	return &pb.TaskResponse{
		Success: true,
		Message: fmt.Sprintf("Task [%s] with ID [%s] routed successfully", in.GetTaskType(), taskID),
	}, nil
}

// setupExchangesAndQueues declares all exchanges and queues, then binds them together.
// This runs ONCE at startup. After this, publishing is all that's needed.
// Think of this as the "wiring diagram" for the whole messaging system.
func setupExchangesAndQueues(ch *amqp.Channel) error {
	log.Println("--- Setting up exchanges and queues ---")

	// --- Step 0: DLX Setup ---
	if err := ch.ExchangeDeclare(DLXExchange, "fanout", true, false, false, false, nil); err != nil {
		return fmt.Errorf("failed to declare dlx exchange: %w", err)
	}
	_, err := ch.QueueDeclare(
		"dlq", // name
		true,  // durable
		false, // auto-delete
		false, // exclusive
		false, // no-wait
		amqp.Table{"x-queue-type": "quorum"},
	)
	if err != nil {
		return fmt.Errorf("failed to declare dlq: %w", err)
	}
	if err := ch.QueueBind("dlq", "", DLXExchange, false, nil); err != nil {
		return fmt.Errorf("failed to bind dlq to dlx: %w", err)
	}
	log.Printf("  ✓ DLX and DLQ setup complete")

	// --- Step 1: Declare the two queues (Quorum type for high availability) ---
	for _, qName := range []string{"queue_A", "queue_B"} {
		_, err := ch.QueueDeclare(
			qName, // name
			true,  // durable: survives broker restarts
			false, // auto-delete: don't delete when last consumer disconnects
			false, // exclusive: other connections can use this queue
			false, // no-wait: wait for server to confirm
			amqp.Table{
				"x-queue-type":           "quorum",
				"x-dead-letter-exchange": DLXExchange,
			}, // Quorum queue for Raft-based HA, DLX for dead letters
		)
		if err != nil {
			return fmt.Errorf("failed to declare queue %s: %w", qName, err)
		}
		log.Printf("  ✓ Queue declared: %s", qName)
	}

	// --- Step 2: DIRECT Exchange ---
	// ExchangeDeclare args: (name, kind, durable, autoDelete, internal, noWait, args)
	if err := ch.ExchangeDeclare(DirectExchange, "direct", true, false, false, false, nil); err != nil {
		return fmt.Errorf("failed to declare direct exchange: %w", err)
	}
	// Bind queue_A to direct exchange with routing key "A"
	// When a message arrives with routing_key="A", ONLY queue_A gets it.
	if err := ch.QueueBind("queue_A", "A", DirectExchange, false, nil); err != nil {
		return fmt.Errorf("failed to bind queue_A to direct exchange: %w", err)
	}
	// Bind queue_B to direct exchange with routing key "B"
	if err := ch.QueueBind("queue_B", "B", DirectExchange, false, nil); err != nil {
		return fmt.Errorf("failed to bind queue_B to direct exchange: %w", err)
	}
	log.Printf("  ✓ Direct exchange '%s': queue_A←'A',  queue_B←'B'", DirectExchange)

	// --- Step 3: FANOUT Exchange ---
	if err := ch.ExchangeDeclare(FanoutExchange, "fanout", true, false, false, false, nil); err != nil {
		return fmt.Errorf("failed to declare fanout exchange: %w", err)
	}
	// Fanout ignores routing keys — just bind both queues, they both get every message.
	if err := ch.QueueBind("queue_A", "", FanoutExchange, false, nil); err != nil {
		return fmt.Errorf("failed to bind queue_A to fanout exchange: %w", err)
	}
	if err := ch.QueueBind("queue_B", "", FanoutExchange, false, nil); err != nil {
		return fmt.Errorf("failed to bind queue_B to fanout exchange: %w", err)
	}
	log.Printf("  ✓ Fanout exchange '%s': queue_A and queue_B both bound (all messages go to both)", FanoutExchange)

	// --- Step 4: TOPIC Exchange ---
	if err := ch.ExchangeDeclare(TopicExchange, "topic", true, false, false, false, nil); err != nil {
		return fmt.Errorf("failed to declare topic exchange: %w", err)
	}
	// "task.A.#" — the '#' wildcard means zero or more words.
	//   Matches: "task.A.urgent", "task.A.normal", "task.A.anything.else"
	if err := ch.QueueBind("queue_A", "task.A.#", TopicExchange, false, nil); err != nil {
		return fmt.Errorf("failed to bind queue_A (task.A.#) to topic exchange: %w", err)
	}
	// "task.B.#" — matches any key starting with "task.B."
	if err := ch.QueueBind("queue_B", "task.B.#", TopicExchange, false, nil); err != nil {
		return fmt.Errorf("failed to bind queue_B (task.B.#) to topic exchange: %w", err)
	}
	// "task.all.#" — BOTH queues are bound to this pattern.
	//   A message with key "task.all.broadcast" goes to BOTH queue_A and queue_B.
	if err := ch.QueueBind("queue_A", "task.all.#", TopicExchange, false, nil); err != nil {
		return fmt.Errorf("failed to bind queue_A (task.all.#) to topic exchange: %w", err)
	}
	if err := ch.QueueBind("queue_B", "task.all.#", TopicExchange, false, nil); err != nil {
		return fmt.Errorf("failed to bind queue_B (task.all.#) to topic exchange: %w", err)
	}
	log.Printf("  ✓ Topic exchange '%s':", TopicExchange)
	log.Printf("      queue_A ← 'task.A.#'   (e.g., task.A.urgent)")
	log.Printf("      queue_B ← 'task.B.#'   (e.g., task.B.normal)")
	log.Printf("      BOTH    ← 'task.all.#' (e.g., task.all.broadcast)")

	// --- Step 5: HEADER Exchange ---
	// Header exchange routes based on message headers.
	// We bind queue_A to receive messages where header "type" = "A",
	// and queue_B where "type" = "B".
	if err := ch.ExchangeDeclare(HeaderExchange, "headers", true, false, false, false, nil); err != nil {
		return fmt.Errorf("failed to declare header exchange: %w", err)
	}
	// Bind queue_A with match-all headers requiring type=A
	if err := ch.QueueBind("queue_A", "", HeaderExchange, false, amqp.Table{"x-match": "all", "type": "A"}); err != nil {
		return fmt.Errorf("failed to bind queue_A to header exchange: %w", err)
	}
	// Bind queue_B with match-all headers requiring type=B
	if err := ch.QueueBind("queue_B", "", HeaderExchange, false, amqp.Table{"x-match": "all", "type": "B"}); err != nil {
		return fmt.Errorf("failed to bind queue_B to header exchange: %w", err)
	}
	log.Printf("  ✓ Header exchange '%s' with bindings for queue_A (type=A) and queue_B (type=B)", HeaderExchange)

	log.Println("--- Setup complete ---")

	return nil
}

func main() {
	if err := godotenv.Load(); err != nil {
		log.Println("No .env file found or error loading it")
	}

	defaultRmq := os.Getenv("RABBITMQ_URL")
	if defaultRmq == "" {
		defaultRmq = "amqp://guest:guest@localhost:5672/"
	}

	port := flag.Int("port", 50051, "The server port")
	rmq := flag.String("rmq", defaultRmq, "RabbitMQ URL")
	flag.Parse()

	// Connect to RabbitMQ broker
	conn, err := amqp.Dial(*rmq)
	if err != nil {
		log.Fatalf("Failed to connect to RabbitMQ: %v", err)
	}
	defer conn.Close()

	// Open a channel (like a virtual connection inside the TCP connection)
	ch, err := conn.Channel()
	if err != nil {
		log.Fatalf("Failed to open a channel: %v", err)
	}
	defer ch.Close()

	// Declare all exchanges, queues, and bindings at startup
	if err := setupExchangesAndQueues(ch); err != nil {
		log.Fatalf("Exchange/queue setup failed: %v", err)
	}

	// Start the gRPC server
	lis, err := net.Listen("tcp", fmt.Sprintf(":%d", *port))
	if err != nil {
		log.Fatalf("Failed to listen: %v", err)
	}

	s := grpc.NewServer()
	pb.RegisterTaskServiceServer(s, &server{amqpChannel: ch})
	log.Printf("Producer gRPC server listening on :%d", *port)
	if err := s.Serve(lis); err != nil {
		log.Fatalf("Failed to serve: %v", err)
	}
}
