#!/usr/bin/env bash
# Regenerates Go code from task_queue.proto.
# Requires: protoc, protoc-gen-go, protoc-gen-go-grpc
set -euo pipefail

PROTO_FILE="task_queue.proto"
OUT_DIR="taskqueue"

mkdir -p "$OUT_DIR"

protoc \
  --go_out="$OUT_DIR" --go_opt=paths=source_relative \
  --go-grpc_out="$OUT_DIR" --go-grpc_opt=paths=source_relative \
  "$PROTO_FILE"

echo "Generated gRPC code in ./$OUT_DIR/"
