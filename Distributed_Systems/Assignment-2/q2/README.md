# Distributed Task Queue Management System

A distributed task queue system using gRPC where Job Clients submit CPU and IO tasks, Worker Clients process them, and a central Task Queue Server manages assignment, failure detection, and re-queuing.

## Features

- **Dual Task Queues**: Separate FIFO queues for CPU-intensive and IO-intensive tasks
- **Worker Specialization**: Workers register as CPU-only, IO-only, or BOTH
- **Server-Pushed Tasks**: Server streams tasks to workers as they become available
- **Heartbeat Monitoring**: Server detects dead workers after 3 missed heartbeats (15 s)
- **Automatic Failover**: Failed tasks are re-queued at the front for immediate reassignment
- **Live Status Polling**: Job Client automatically prints status changes as they happen

## Files

- `task_queue.proto` - Protocol Buffer service and message definitions
- `taskqueue/` - Generated gRPC Go code
- `server.go` - Task Queue Server (queue logic, scheduling, failure detection)
- `worker.go` - Worker Client (task processing, heartbeats)
- `job_client.go` - Job Client (task submission, status polling)
- `generate_grpc.sh` - Script to regenerate gRPC code from the proto file
- `go.mod` - Go module definition

## Prerequisites

- Go 1.21 or higher
- gRPC Go library
- Protocol Buffers compiler (only needed to regenerate code)

## Installation

1. Install dependencies:
```bash
go mod download
```

2. Build the binaries:
```bash
make build

or

go build -o server server.go
go build -o worker worker.go
go build -o job_client job_client.go
```

## Usage

### Starting the Server

The server accepts a single address argument:

```bash
# Terminal 1
./server localhost:50051
[Server] Listening on localhost:50051
```

### Registering Workers

Workers accept the server address and their type (`CPU`, `IO`, or `BOTH`):

```bash
# Terminal 2 – CPU worker
./worker localhost:50051 CPU
[Worker] Registered with ID: W1 (type: CPU)
[Worker W1] Waiting for tasks...

# Terminal 3 – IO worker
./worker localhost:50051 IO
[Worker] Registered with ID: W2 (type: IO)
[Worker W2] Waiting for tasks...

# Terminal 4 – BOTH worker (handles either queue)
./worker localhost:50051 BOTH
[Worker] Registered with ID: W3 (type: BOTH)
[Worker W3] Waiting for tasks...
```

### Submitting Tasks via Job Client

```bash
# Terminal 5
./job_client localhost:50051
[Client] Connected to localhost:50051
```

#### Commands

| Command | Description |
|---|---|
| `submit CPU <N>` | Submit a CPU task (N×N matrix multiplication) |
| `submit IO <secs>` | Submit an IO task (sleep for N seconds) |
| `status <task-id>` | Query the current status of a task |
| `help` | Show available commands |
| `quit` / `exit` | Exit the client |

#### Example Session

```
> submit CPU 100
[Client] Task submitted. ID: T1 (CPU, payload=100)
[Client] Task T1: Processing (Worker W1)

> submit IO 5
[Client] Task submitted. ID: T2 (IO, payload=5)
[Client] Task T2: Processing (Worker W2)

> status T1
[Client] Task T1: Completed

> submit CPU 200
[Client] Task submitted. ID: T3 (CPU, payload=200)
[Client] Task T3: Queued
[Client] Task T3: Processing (Worker W1)
[Client] Task T3: Completed
```

After submitting a task, the client automatically polls its status every 2 seconds and prints each status transition until the task reaches `Completed` or `Failed`.

## Implementation Details

### Server (`server.go`)

- **SubmitTask**: Generates a unique task ID, appends to the matching FIFO queue, and immediately tries to assign it to an available worker
- **GetTaskStatus**: Returns the current status and assigned worker ID for any task
- **RegisterWorker**: Creates worker state with a buffered task channel and immediately tries to assign a queued task
- **RequestTask**: Keeps a server-streaming RPC open; pushes tasks into the stream via an internal channel as they are assigned
- **SendHeartbeat**: Updates the worker's last-seen timestamp
- **UpdateTaskStatus**: Updates the task record; on `Completed`/`Failed`, frees the worker and assigns the next matching task
- **heartbeatChecker**: Background goroutine that ticks every 5 s, marks workers dead after 15 s of silence, and re-queues their in-progress tasks at the front of the queue
- Thread-safe throughout using a single mutex

### Worker (`worker.go`)

- **Task processing**:
  - `CPU` task: naive O(n³) N×N matrix multiplication to generate real CPU load
  - `IO` task: `time.Sleep` for the given number of seconds to simulate network/disk I/O
- **Heartbeats**: Sent every 5 seconds in a background goroutine
- **Status reporting**: Sends `Processing` on task start and `Completed`/`Failed` on finish via `UpdateTaskStatus`
- Exits cleanly when the server closes the stream (e.g., worker marked dead)

### Job Client (`job_client.go`)

- **Polling**: Each submitted task spawns a goroutine that polls `GetTaskStatus` every 2 seconds and prints when the status changes
- **Manual query**: The `status` command performs a single on-demand lookup
- **Interactive CLI**: `bufio.Scanner`-based REPL with help text

### Protocol Buffers (`task_queue.proto`)

- **TaskRequest/TaskResponse**: Submit a task, receive a unique ID
- **TaskStatusRequest/TaskStatusResponse**: Query task status and assigned worker
- **WorkerConfig/WorkerId**: Register a worker, receive a unique ID
- **Task**: Payload pushed from server to worker over a streaming RPC
- **Heartbeat/Acknowledge**: Liveness signalling
- **TaskStatusUpdate/Acknowledge**: Worker reports task completion

## Task Assignment Rules

- CPU workers receive tasks only from the CPU queue
- IO workers receive tasks only from the IO queue
- BOTH workers receive from either queue; when both queues are non-empty, the task with the earliest arrival time is chosen first
- A worker receives at most one task at a time; the next task is not sent until `UpdateTaskStatus` is called with `Completed` or `Failed`

## Failure Detection and Recovery

1. Workers send heartbeats every **5 seconds**
2. The server checks every **5 seconds**; a worker with no heartbeat for **≥ 15 seconds** is marked dead
3. On detection:
   - The worker's task stream is closed via a `doneChan` signal
   - The in-progress task is re-queued at the **front** of its queue with status `Queued`
   - The server immediately tries to assign the task to any available compatible worker
4. The Job Client will see the new `Queued` → `Processing` transitions the next time it polls

## Error Handling

- Server connection failures are reported and exit the binary
- RPC calls use a 5-second context timeout
- Invalid payloads (non-integer strings) cause the task to be marked `Failed`
- Heartbeat errors are logged but do not crash the worker

## Regenerating gRPC Code

If you modify `task_queue.proto`, regenerate the Go code with:

```bash
chmod +x generate_grpc.sh
./generate_grpc.sh
```

Requires `protoc`, `protoc-gen-go`, and `protoc-gen-go-grpc` to be installed and on `$PATH`.
