# K-Nearest Neighbors (KNN) Distributed System

A distributed k-NN implementation using gRPC where multiple servers hold partitions of the dataset and clients query for global k-nearest neighbors.

## Features

- **Distributed Data Storage**: Dataset is partitioned across multiple gRPC servers
- **Dynamic Data Upload**: Client splits and uploads CSV data to servers
- **Global KNN Query**: Aggregates results from all servers to find global k-nearest neighbors
- **Euclidean Distance**: Uses standard Euclidean distance metric
- **Arbitrary Dimensionality**: Supports data points with any number of features

## Files

- `knn.proto` - Protocol Buffer service definition
- `knn/knn.pb.go` - Generated gRPC code
- `knn_server.go` - gRPC server implementation
- `knn_client.go` - Client implementation with CLI
- `data.csv` - Sample 2D dataset
- `go.mod` - Go module definition

## Prerequisites

- Go 1.21 or higher
- gRPC Go library
- Protocol Buffers compiler (for regenerating code)

## Installation

1. Install dependencies:
```bash
go mod download
```

2. Build the binaries:
```bash
go build -o knn_server knn_server.go
go build -o knn_client knn_client.go
```

## Usage

### Starting Servers

Start multiple servers on different ports. Each server accepts its port number as a command-line argument:

```bash
# Terminal 1
./knn_server 50051

# Terminal 2
./knn_server 50052

# Terminal 3
./knn_server 50053
```

### Running the Client

Start the client with the list of server addresses:

```bash
./knn_client localhost:50051 localhost:50052 localhost:50053
```

### Client Menu Options

The client provides an interactive CLI with three options:

#### 1. Add Data
Uploads a CSV dataset to the servers. The data is automatically partitioned into contiguous chunks across all servers.

```
Enter choice: 1
Enter dataset filename: data.csv
```

**Data Format**: CSV file with comma-separated floating-point values. Each row is a data point.

Example (`data.csv`):
```
1.0,2.0
3.0,4.0
5.0,6.0
7.0,8.0
2.0,1.0
4.0,3.0
```

**Partitioning Logic**: 
- Data points are split into approximately equal contiguous chunks
- If not evenly divisible, extra points go to the first servers
- Example: 6 points across 3 servers → 2 points each

#### 2. Find KNN
Queries all servers for k-nearest neighbors and aggregates the results:

```
Enter choice: 2
Enter query point (comma-separated values): 2.0,3.0
Enter k: 3
```

**Output Example**:
```
Global 3-Nearest Neighbors of (2.0, 3.0):
(1.0, 2.0) - distance: 1.41
(3.0, 4.0) - distance: 1.41
(2.0, 1.0) - distance: 2.00
```

#### 3. End
Exits the program.

## Example Workflow

```bash
# Start 3 servers
./knn_server 50051 &
./knn_server 50052 &
./knn_server 50053 &

# Run client
./knn_client localhost:50051 localhost:50052 localhost:50053

# In client menu:
# 1. Add Data → data.csv
# 2. Find KNN → query: 2.0,3.0, k: 3
# 3. End
```

## Implementation Details

### Server (`knn_server.go`)
- **UploadData**: Stores data points (replaces previous data)
- **QueryKNN**: Computes k-nearest neighbors from local subset
- Thread-safe using mutex locks
- Returns all points if k exceeds available data

### Client (`knn_client.go`)
- **Data Partitioning**: Splits CSV file into contiguous chunks
- **Upload**: Distributes partitions to servers via UploadData RPC
- **Query**: Sends KNN request to all servers in parallel
- **Aggregation**: Merges results and sorts by distance to find global k-NN
- **Distance Calculation**: Euclidean distance metric

### Protocol Buffers (`knn.proto`)
- **DataPoint**: Array of feature values
- **UploadRequest/Response**: Bulk data upload
- **KNNRequest/Response**: Query and neighbor results
- **Neighbor**: Point with computed distance

## Error Handling

- Server connection failures are logged with warnings
- Invalid CSV formats are reported
- Network timeouts set to 5 seconds per request
- Graceful handling of fewer neighbors than requested k

## Notes

- Each UploadData call replaces all previous data on that server
- Re-uploading requires sending the entire dataset again
- Tie-breaking for equal distances uses arrival order (stable sort)
- Supports arbitrary feature dimensions (all points must have same dimensionality)
