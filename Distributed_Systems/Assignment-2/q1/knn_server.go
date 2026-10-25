package main

import (
	"context"
	"fmt"
	"log"
	"math"
	"net"
	"os"
	"sort"
	"sync"

	"google.golang.org/grpc"
	pb "knn_system/knn"
)

type server struct {
	pb.UnimplementedKNNServiceServer
	mu    sync.RWMutex
	data  []*pb.DataPoint
}

func (s *server) UploadData(ctx context.Context, req *pb.UploadRequest) (*pb.UploadResponse, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	
	s.data = req.DataPoints
	log.Printf("Stored %d data points", len(s.data))
	
	return &pb.UploadResponse{
		Success:      true,
		PointsStored: int32(len(s.data)),
	}, nil
}

func (s *server) QueryKNN(ctx context.Context, req *pb.KNNRequest) (*pb.KNNResponse, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	
	var neighbors []*pb.Neighbor
	
	for _, point := range s.data {
		dist := euclideanDistance(req.QueryPoint, point)
		neighbors = append(neighbors, &pb.Neighbor{
			Point:    point,
			Distance: dist,
		})
	}
	
	// Sort by distance
	sort.Slice(neighbors, func(i, j int) bool {
		return neighbors[i].Distance < neighbors[j].Distance
	})
	
	// Return up to k neighbors
	k := int(req.K)
	if k > len(neighbors) {
		k = len(neighbors)
	}
	
	return &pb.KNNResponse{
		Neighbors: neighbors[:k],
	}, nil
}

func euclideanDistance(p1, p2 *pb.DataPoint) float64 {
	if len(p1.Features) != len(p2.Features) {
		return math.MaxFloat64
	}
	
	sum := 0.0
	for i := range p1.Features {
		diff := p1.Features[i] - p2.Features[i]
		sum += diff * diff
	}
	return math.Sqrt(sum)
}

func main() {
	if len(os.Args) < 2 {
		log.Fatal("Usage: knn_server <port>")
	}
	
	port := os.Args[1]
	lis, err := net.Listen("tcp", ":"+port)
	if err != nil {
		log.Fatalf("Failed to listen: %v", err)
	}
	
	s := grpc.NewServer()
	pb.RegisterKNNServiceServer(s, &server{})
	
	fmt.Printf("Server listening on port %s\n", port)
	if err := s.Serve(lis); err != nil {
		log.Fatalf("Failed to serve: %v", err)
	}
}
