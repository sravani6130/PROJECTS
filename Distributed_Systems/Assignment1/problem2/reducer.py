#!/usr/bin/env python3
import sys

# Damping factor d=0.85 [cite: 89]
D = 0.85

if len(sys.argv) < 2:
    sys.exit(1)

try:
    N = int(sys.argv[1])
except ValueError:
    sys.exit(1)

current_node = None
structure = ""
vote_sum = 0.0

for line in sys.stdin:
    line = line.strip()
    if not line:
        continue

    try:
        # Split into Key (Node) and Value
        node, value = line.split('\t', 1)
    except ValueError:
        continue

    # If we switched to a new node, emit the result for the previous one
    if current_node and node != current_node:
        # Formula: PR(v) = (1-d)/N + d * sum(incoming_votes) 
        new_pr = ((1 - D) / N) + (D * vote_sum)
        
        # Output format: Node <TAB> Neighbors <TAB> PageRank
        # We MUST output neighbors so they are available for the next iteration's mapper
        print(f"{current_node}\t{structure}\t{new_pr:.6f}")
        
        # Reset for new node
        vote_sum = 0.0
        structure = ""

    current_node = node

    # Process values
    if value.startswith("NODES:"):
        structure = value.split(":", 1)[1]
    elif value.startswith("VAL:"):
        try:
            vote_sum += float(value.split(":", 1)[1])
        except ValueError:
            pass

# Process the last node
if current_node:
    new_pr = ((1 - D) / N) + (D * vote_sum)
    print(f"{current_node}\t{structure}\t{new_pr:.6f}")
