.PHONY: build clean proto deps help

# Build all three binaries
build:
	@echo "Building Task Queue System..."
	go build -o server server.go
	go build -o worker worker.go
	go build -o job_client job_client.go
	@echo "Build complete!"

# Remove build artifacts
clean:
	rm -f server worker job_client

# Regenerate gRPC code from proto file
proto:
	chmod +x generate_grpc.sh
	./generate_grpc.sh

# Download Go module dependencies
deps:
	go mod download

# Show usage hints
run-server:
	@echo "Start the server:"
	@echo "  ./server localhost:50051"

run-worker:
	@echo "Start a worker (type = CPU | IO | BOTH):"
	@echo "  ./worker localhost:50051 CPU"
	@echo "  ./worker localhost:50051 IO"
	@echo "  ./worker localhost:50051 BOTH"

run-client:
	@echo "Start the job client:"
	@echo "  ./job_client localhost:50051"

# Help
help:
	@echo "Task Queue System – Makefile"
	@echo ""
	@echo "Targets:"
	@echo "  build        Build server, worker, and job_client binaries"
	@echo "  clean        Remove build artifacts"
	@echo "  proto        Regenerate gRPC Go code from task_queue.proto"
	@echo "  deps         Download Go module dependencies"
	@echo "  run-server   Show how to start the server"
	@echo "  run-worker   Show how to start a worker"
	@echo "  run-client   Show how to start the job client"
	@echo "  help         Show this message"
	@echo ""
	@echo "Quick Start:"
	@echo "  1. make build"
	@echo "  2. ./server localhost:50051                  (Terminal 1)"
	@echo "  3. ./worker localhost:50051 CPU              (Terminal 2)"
	@echo "  4. ./worker localhost:50051 IO               (Terminal 3)"
	@echo "  5. ./job_client localhost:50051              (Terminal 4)"

all: build
