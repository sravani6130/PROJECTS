.PHONY: build clean run-servers run-client test help

# Build targets
build:
	@echo "Building KNN system..."
	go build -o knn_server knn_server.go
	go build -o knn_client knn_client.go
	@echo "Build complete!"

# Clean build artifacts
clean:
	rm -f knn_server knn_client

# Install dependencies
deps:
	go mod download

# Run 3 servers (requires terminal multiplexer or separate terminals)
run-servers:
	@echo "Start servers in separate terminals:"
	@echo "  ./knn_server 50051"
	@echo "  ./knn_server 50052"
	@echo "  ./knn_server 50053"

# Run client
run-client:
	@echo "Run client with:"
	@echo "  ./knn_client localhost:50051 localhost:50052 localhost:50053"

# Help
help:
	@echo "KNN Distributed System - Makefile"
	@echo ""
	@echo "Targets:"
	@echo "  build        - Build server and client binaries"
	@echo "  clean        - Remove build artifacts"
	@echo "  deps         - Download Go dependencies"
	@echo "  run-servers  - Show how to run servers"
	@echo "  run-client   - Show how to run client"
	@echo "  help         - Show this help message"
	@echo ""
	@echo "Quick Start:"
	@echo "  1. make build"
	@echo "  2. Start 3 servers in separate terminals (see make run-servers)"
	@echo "  3. Run client (see make run-client)"

# Default target
all: build
