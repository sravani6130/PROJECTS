package main

import (
	"bytes"
	"flag"
	"log"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/joho/godotenv"
	amqp "github.com/rabbitmq/amqp091-go"
)

func main() {
	if err := godotenv.Load(); err != nil {
		log.Println("No .env file found or error loading it")
	}

	defaultRmq := os.Getenv("RABBITMQ_URL")
	if defaultRmq == "" {
		defaultRmq = "amqp://guest:guest@localhost:5672/"
	}

	queueName := flag.String("queue", "queue_A", "Queue to consume from (queue_A or queue_B)")
	rmq := flag.String("rmq", defaultRmq, "RabbitMQ URL")
	flag.Parse()

	conn, err := amqp.Dial(*rmq)
	if err != nil {
		log.Fatalf("Failed to connect to RabbitMQ: %v", err)
	}
	defer conn.Close()

	ch, err := conn.Channel()
	if err != nil {
		log.Fatalf("Failed to open a channel: %v", err)
	}
	defer ch.Close()

	// Declare the queue
	q, err := ch.QueueDeclare(
		*queueName,                           // name
		true,                                 // durable
		false,                                // delete when unused
		false,                                // exclusive
		false,                                // no-wait
		amqp.Table{
			"x-queue-type":           "quorum",
			"x-dead-letter-exchange": "task_dlx_exchange",
		}, // arguments
	)
	if err != nil {
		log.Fatalf("Failed to declare a queue: %v", err)
	}

	// QoS to ensure consumer only gets 1 message at a time
	err = ch.Qos(
		1,     // prefetch count
		0,     // prefetch size
		false, // global
	)
	if err != nil {
		log.Fatalf("Failed to set QoS: %v", err)
	}

	msgs, err := ch.Consume(
		q.Name, // queue
		"",     // consumer
		false,  // auto-ack
		false,  // exclusive
		false,  // no-local
		false,  // no-wait
		nil,    // args
	)
	if err != nil {
		log.Fatalf("Failed to register a consumer: %v", err)
	}

	var forever chan struct{}

	go func() { // goroutine to run the function concurrently
		for d := range msgs {
			bodyStr := string(bytes.TrimSpace(d.Body))
			parts := strings.Split(bodyStr, "|")
			
			var taskID string
			var duration int
			var err error

			if len(parts) == 2 {
				taskID = parts[0]
				duration, err = strconv.Atoi(parts[1])
			} else {
				// Fallback for old format
				taskID = "unknown"
				duration, err = strconv.Atoi(bodyStr)
			}

			if err != nil {
				log.Printf("Error parsing message '%s': %v", bodyStr, err)
				d.Nack(false, false)
				continue
			}

			log.Printf("[METRIC] CONSUMER_RECEIVE: task_id=%s, queue=%s, timestamp=%s",
				taskID, *queueName, time.Now().Format(time.RFC3339Nano))

			// Reject messages with time > 100 to push them to DLX
			if duration > 100 {
				log.Printf("Duration > 100 (%d). Rejecting task to DLX...", duration)
				d.Nack(false, false)
				continue
			}

			log.Printf("Processing task %s (duration %ds)...", taskID, duration)
			time.Sleep(time.Duration(duration) * time.Second)
			
			log.Printf("[METRIC] CONSUMER_COMPLETE: task_id=%s, queue=%s, timestamp=%s",
				taskID, *queueName, time.Now().Format(time.RFC3339Nano))

			// Acknowledge message
			d.Ack(false)
		}
	}()

	log.Printf(" [*] Consumer waiting for messages on %s. To exit press CTRL+C", q.Name)
	<-forever
}
