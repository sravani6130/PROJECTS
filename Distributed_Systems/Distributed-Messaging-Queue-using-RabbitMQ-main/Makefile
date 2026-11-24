# Makefile for Distributed Messaging Queue

.PHONY: all build run clean docker-up docker-down proto test

# Default target
all: build

# Build all binaries
build:
	@echo "Building binaries..."
	go build -o bin/producer ./producer/main.go
	go build -o bin/consumer ./consumer/main.go
	go build -o bin/client ./client/main.go

# Run infrastructure
up:
	docker-compose up -d
	@echo "Infrastructure is up. Dashboard at http://localhost:15672"

# Stop infrastructure
down:
	docker-compose down

# Generate gRPC code
proto:
	protoc --go_out=. --go_opt=paths=source_relative \
		--go-grpc_out=. --go-grpc_opt=paths=source_relative \
		proto/task.proto

# Run unit tests
test:
	go test -v ./...

# Clean binaries
clean:
	rm -rf bin/
	@echo "Cleaned binaries."

# Help message
help:
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  build       Build producer, consumer, and client"
	@echo "  up          Start RabbitMQ cluster with Docker Compose"
	@echo "  down        Stop RabbitMQ cluster"
	@echo "  proto       Generate gRPC code from proto files"
	@echo "  test        Run Go tests"
	@echo "  clean       Remove build artifacts"
