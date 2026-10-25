#!/bin/bash

# Script to regenerate gRPC Go code from proto file
# Requires: protoc, protoc-gen-go, protoc-gen-go-grpc

echo "Regenerating gRPC code from knn.proto..."

# Check if protoc is installed
if ! command -v protoc &> /dev/null; then
    echo "Error: protoc not found. Install with:"
    echo "  Ubuntu/Debian: sudo apt-get install protobuf-compiler"
    echo "  macOS: brew install protobuf"
    exit 1
fi

# Check if Go protoc plugins are installed
if ! command -v protoc-gen-go &> /dev/null; then
    echo "Installing protoc-gen-go..."
    go install google.golang.org/protobuf/cmd/protoc-gen-go@latest
fi

if ! command -v protoc-gen-go-grpc &> /dev/null; then
    echo "Installing protoc-gen-go-grpc..."
    go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest
fi

# Add Go bin to PATH if needed
export PATH="$PATH:$(go env GOPATH)/bin"

# Generate the code
protoc --go_out=. --go_opt=paths=source_relative \
       --go-grpc_out=. --go-grpc_opt=paths=source_relative \
       knn.proto

if [ $? -eq 0 ]; then
    echo "Successfully generated gRPC code!"
    echo "Generated files:"
    ls -lh knn/knn.pb.go knn/knn_grpc.pb.go 2>/dev/null || ls -lh knn/*.go
else
    echo "Failed to generate gRPC code"
    exit 1
fi
