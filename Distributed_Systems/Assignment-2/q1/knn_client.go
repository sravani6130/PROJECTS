package main

import (
	"bufio"
	"context"
	"encoding/csv"
	"fmt"
	"log"
	"os"
	"sort"
	"strconv"
	"strings"
	"time"

	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
	pb "knn_system/knn"
)

type client struct {
	servers []string
	conns   []*grpc.ClientConn
	clients []pb.KNNServiceClient
}

func newClient(servers []string) (*client, error) {
	c := &client{servers: servers}
	
	for _, addr := range servers {
		conn, err := grpc.Dial(addr, grpc.WithTransportCredentials(insecure.NewCredentials()))
		if err != nil {
			return nil, fmt.Errorf("failed to connect to %s: %v", addr, err)
		}
		c.conns = append(c.conns, conn)
		c.clients = append(c.clients, pb.NewKNNServiceClient(conn))
	}
	
	return c, nil
}

func (c *client) close() {
	for _, conn := range c.conns {
		conn.Close()
	}
}

func (c *client) uploadData(filename string) error {
	// Read CSV file
	file, err := os.Open(filename)
	if err != nil {
		return err
	}
	defer file.Close()
	
	reader := csv.NewReader(file)
	rows, err := reader.ReadAll()
	if err != nil {
		return err
	}
	
	// Parse data points
	var dataPoints []*pb.DataPoint
	for _, row := range rows {
		var features []float64
		for _, val := range row {
			f, err := strconv.ParseFloat(strings.TrimSpace(val), 64)
			if err != nil {
				return err
			}
			features = append(features, f)
		}
		dataPoints = append(dataPoints, &pb.DataPoint{Features: features})
	}
	
	// Partition data across servers
	n := len(dataPoints)
	numServers := len(c.servers)
	baseSize := n / numServers
	remainder := n % numServers
	
	start := 0
	for i := 0; i < numServers; i++ {
		size := baseSize
		if i < remainder {
			size++
		}
		
		end := start + size
		if end > n {
			end = n
		}
		
		partition := dataPoints[start:end]
		
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		resp, err := c.clients[i].UploadData(ctx, &pb.UploadRequest{DataPoints: partition})
		cancel()
		
		if err != nil {
			return fmt.Errorf("failed to upload to server %d: %v", i+1, err)
		}
		
		fmt.Printf("Uploaded %d points to server %d (addr: %s)\n", resp.PointsStored, i+1, c.servers[i])
		start = end
	}
	
	return nil
}

func (c *client) findKNN(queryPoint []float64, k int) error {
	query := &pb.DataPoint{Features: queryPoint}
	
	var allNeighbors []*pb.Neighbor
	
	// Query all servers
	for i, client := range c.clients {
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		resp, err := client.QueryKNN(ctx, &pb.KNNRequest{
			QueryPoint: query,
			K:          int32(k),
		})
		cancel()
		
		if err != nil {
			log.Printf("Warning: server %d query failed: %v", i+1, err)
			continue
		}
		
		allNeighbors = append(allNeighbors, resp.Neighbors...)
	}
	
	// Sort all neighbors by distance
	sort.Slice(allNeighbors, func(i, j int) bool {
		return allNeighbors[i].Distance < allNeighbors[j].Distance
	})
	
	// Take top k
	if k > len(allNeighbors) {
		k = len(allNeighbors)
	}
	
	// Print results
	fmt.Printf("\nGlobal %d-Nearest Neighbors of (", k)
	for i, f := range queryPoint {
		if i > 0 {
			fmt.Print(", ")
		}
		fmt.Printf("%.1f", f)
	}
	fmt.Println("):")
	
	for _, neighbor := range allNeighbors[:k] {
		fmt.Print("(")
		for i, f := range neighbor.Point.Features {
			if i > 0 {
				fmt.Print(", ")
			}
			fmt.Printf("%.1f", f)
		}
		fmt.Printf(") - distance: %.2f\n", neighbor.Distance)
	}
	
	return nil
}

func main() {
	if len(os.Args) < 2 {
		log.Fatal("Usage: knn_client <server1> <server2> ...")
	}
	
	servers := os.Args[1:]
	c, err := newClient(servers)
	if err != nil {
		log.Fatal(err)
	}
	defer c.close()
	
	fmt.Printf("Connected to %d servers\n", len(servers))
	
	scanner := bufio.NewScanner(os.Stdin)
	
	for {
		fmt.Println("\n=== KNN Client Menu ===")
		fmt.Println("1. Add Data")
		fmt.Println("2. Find KNN")
		fmt.Println("3. End")
		fmt.Print("Enter choice: ")
		
		if !scanner.Scan() {
			break
		}
		
		choice := strings.TrimSpace(scanner.Text())
		
		switch choice {
		case "1":
			fmt.Print("Enter dataset filename: ")
			if !scanner.Scan() {
				break
			}
			filename := strings.TrimSpace(scanner.Text())
			
			if err := c.uploadData(filename); err != nil {
				fmt.Printf("Error uploading data: %v\n", err)
			} else {
				fmt.Println("Data uploaded successfully!")
			}
			
		case "2":
			fmt.Print("Enter query point (comma-separated values): ")
			if !scanner.Scan() {
				break
			}
			pointStr := strings.TrimSpace(scanner.Text())
			
			parts := strings.Split(pointStr, ",")
			var queryPoint []float64
			for _, p := range parts {
				val, err := strconv.ParseFloat(strings.TrimSpace(p), 64)
				if err != nil {
					fmt.Printf("Invalid number: %s\n", p)
					continue
				}
				queryPoint = append(queryPoint, val)
			}
			
			fmt.Print("Enter k: ")
			if !scanner.Scan() {
				break
			}
			k, err := strconv.Atoi(strings.TrimSpace(scanner.Text()))
			if err != nil || k <= 0 {
				fmt.Println("Invalid k value")
				continue
			}
			
			if err := c.findKNN(queryPoint, k); err != nil {
				fmt.Printf("Error finding KNN: %v\n", err)
			}
			
		case "3":
			fmt.Println("Exiting...")
			return
			
		default:
			fmt.Println("Invalid choice")
		}
	}
}
