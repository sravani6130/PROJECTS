package main

import (
	"bufio"
	"context"
	"fmt"
	"log"
	"math/rand"
	"os"
	"strconv"
	"strings"
	"time"

	pb "distributed-broker/proto"
	"github.com/joho/godotenv"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
)

func printHelp() {
	fmt.Println("\n╔══════════════════════════════════════════════════════════════╗")
	fmt.Println("║          Distributed Messaging Queue — Client CLI            ║")
	fmt.Println("╠══════════════════════════════════════════════════════════════╣")
	fmt.Println("║  Exchange Type  │ Command Format            │ Routes to      ║")
	fmt.Println("║─────────────────┼───────────────────────────┼────────────────║")
	fmt.Println("║  Direct         │ classA <seconds>          │ queue_A only   ║")
	fmt.Println("║  Direct         │ classB <seconds>          │ queue_B only   ║")
	fmt.Println("║  Fanout         │ classAB <seconds>         │ queue_A+queue_B║")
	fmt.Println("║  Header         │ classHeaderA <seconds>    │ header type A  ║")
	fmt.Println("║  Header         │ classHeaderB <seconds>    │ header type B  ║")
	fmt.Println("║  Topic          │ classTopic <key> <seconds>│ pattern match  ║")
	fmt.Println("╠══════════════════════════════════════════════════════════════╣")
	fmt.Println("║  Topic routing key examples:                                 ║")
	fmt.Println("║    task.A.urgent     → queue_A only                         ║")
	fmt.Println("║    task.B.normal     → queue_B only                         ║")
	fmt.Println("║    task.all.broadcast→ queue_A AND queue_B                  ║")
	fmt.Println("╠══════════════════════════════════════════════════════════════╣")
	fmt.Println("║  Type 'help' to show this menu. Type 'exit' to quit.        ║")
	fmt.Println("╚══════════════════════════════════════════════════════════════╝")
	fmt.Println()
}

func main() {
	// Load .env file
	if err := godotenv.Load(); err != nil {
		log.Println("No .env file found or error loading it")
	}

	p1 := os.Getenv("PRODUCER_1_URL")
	if p1 == "" {
		p1 = "localhost:50051"
	} else {
		p1 = strings.TrimPrefix(p1, "http://")
	}

	p2 := os.Getenv("PRODUCER_2_URL")
	if p2 == "" {
		p2 = "localhost:50052"
	} else {
		p2 = strings.TrimPrefix(p2, "http://")
	}

	// Client-side load balancing: the client picks a random producer on each request.
	// In a real system this would use a proper load balancer (e.g., Envoy, HAProxy).
	producers := []string{p1, p2}

	reader := bufio.NewReader(os.Stdin)
	printHelp()

	for {
		fmt.Print("-> ")
		text, _ := reader.ReadString('\n')
		text = strings.TrimSpace(text)

		if text == "exit" {
			fmt.Println("Goodbye!")
			break
		}
		if text == "help" || text == "" {
			printHelp()
			continue
		}

		// Parse the command into parts split by spaces
		parts := strings.Fields(text) // strings.Fields splits on any whitespace

		if len(parts) < 2 {
			fmt.Println("ERROR: Too few arguments. Type 'help' for usage.")
			continue
		}

		classStr := parts[0]
		if !strings.HasPrefix(classStr, "class") {
			fmt.Println("ERROR: Command must start with 'class'. Type 'help' for usage.")
			continue
		}

		// Extract the type suffix: "classA" → "A", "classAB" → "AB", "classTopic" → "TOPIC", "classHeaderA" → "HEADER_A", "classHeaderB" → "HEADER_B"
		taskType := strings.ToUpper(strings.TrimPrefix(classStr, "class"))

		var (
			duration   int
			routingKey string
			err        error
		)

		switch taskType {

		// --- Direct and Fanout: format is "classA 10" or "classAB 12" ---
		case "A", "B", "AB":
			if len(parts) != 2 {
				fmt.Printf("ERROR: Expected format: %s <seconds>. Example: %s 10\n", classStr, classStr)
				continue
			}
			duration, err = strconv.Atoi(parts[1])
			if err != nil {
				fmt.Println("ERROR: Duration must be a whole number. Example: classA 10")
				continue
			}

		case "HEADER_A", "HEADER_B":
			// No extra arguments, just duration
			if len(parts) != 2 {
				fmt.Printf("ERROR: Expected format: %s <seconds>. Example: %s 10\n", classStr, classStr)
				continue
			}
			duration, err = strconv.Atoi(parts[1])
			if err != nil {
				fmt.Println("ERROR: Duration must be a whole number. Example: classHeaderA 10")
				continue
			}
			// routingKey remains empty for header exchange
			routingKey = ""

		// --- Topic: format is "classTopic task.A.urgent 8" ---
		case "TOPIC":
			if len(parts) != 3 {
				fmt.Println("ERROR: Expected format: classTopic <routing_key> <seconds>")
				fmt.Println("  Example: classTopic task.A.urgent 8")
				fmt.Println("  Example: classTopic task.all.broadcast 5")
				continue
			}
			routingKey = parts[1]
			duration, err = strconv.Atoi(parts[2])
			if err != nil {
				fmt.Println("ERROR: Duration must be a whole number. Example: classTopic task.A.urgent 10")
				continue
			}

		default:
			fmt.Printf("ERROR: Unknown class %q. Valid: classA, classB, classAB, classTopic\n", classStr)
			continue
		}

		if duration <= 0 {
			fmt.Println("ERROR: Duration must be a positive integer.")
			continue
		}

		// Pick a random producer (client-side load balancing)
		producerAddr := producers[rand.Intn(len(producers))]

		// Open a gRPC connection to the chosen producer.
		// Note: a new connection per request is fine for this demo, but in production
		// you'd maintain a pool of persistent connections.
		conn, err := grpc.Dial(producerAddr, grpc.WithTransportCredentials(insecure.NewCredentials()))
		if err != nil {
			log.Printf("ERROR: Could not connect to producer at %s: %v", producerAddr, err)
			continue
		}

		client := pb.NewTaskServiceClient(conn)

		// Set a 5-second deadline — if the producer doesn't respond in time, give up.
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)

		fmt.Printf("Sending [%s] task (duration=%ds) to producer %s...\n", taskType, duration, producerAddr)

		r, err := client.SubmitTask(ctx, &pb.TaskRequest{
			TaskType:   taskType,
			Duration:   int32(duration),
			RoutingKey: routingKey, // only set for TOPIC, empty string for others
		})

		if err != nil {
			log.Printf("ERROR: SubmitTask failed: %v", err)
		} else {
			if r.GetSuccess() {
				log.Printf("✓ Success: %s", r.GetMessage())
			} else {
				log.Printf("✗ Failed: %s", r.GetMessage())
			}
		}

		cancel()
		conn.Close()
	}
}
