#!/bin/bash

# Test script for KNN system
echo "Building KNN system..."
cd /home/claude/knn_system

# Build the binaries
go build -o knn_server knn_server.go 2>&1
go build -o knn_client knn_client.go 2>&1

if [ ! -f knn_server ] || [ ! -f knn_client ]; then
    echo "Build failed!"
    exit 1
fi

echo "Build successful!"
echo ""
echo "Files created:"
ls -lh knn_server knn_client
echo ""
echo "To run the system:"
echo ""
echo "1. Start servers in separate terminals:"
echo "   ./knn_server 50051"
echo "   ./knn_server 50052"
echo "   ./knn_server 50053"
echo ""
echo "2. Run client:"
echo "   ./knn_client localhost:50051 localhost:50052 localhost:50053"
echo ""
echo "3. Use the menu to:"
echo "   - Upload data.csv"
echo "   - Query with point (2.0,3.0) and k=3"
echo ""
echo "Sample data.csv has been created with 6 points"
