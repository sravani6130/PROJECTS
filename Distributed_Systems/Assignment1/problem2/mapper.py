#!/usr/bin/env python3
import sys

for line in sys.stdin:
    line = line.rstrip('\n')
    if not line:
        continue

    parts = line.split('\t')
    
    # Robust check: We need at least Node and Neighbors (PR might be missing in iter 0 if not handled carefully, but usually 3 parts)
    if len(parts) < 3:
        continue

    node = parts[0]
    neighbors = parts[1]
    
    try:
        pr = float(parts[2])
    except ValueError:
        continue

    # 1. Emit Structure (Required to preserve graph for next iteration)
    # Output: NodeID <TAB> NODES:NeighborList
    print(f"{node}\tNODES:{neighbors}")

    # 2. Emit Votes
    # Only emit votes if there are neighbors
    if neighbors and neighbors.strip() != "":
        nbrs = neighbors.split(',')
        out_degree = len(nbrs)
        if out_degree > 0:
            vote = pr / out_degree
            for n in nbrs:
                # Output: NeighborID <TAB> VAL:VoteAmount
                print(f"{n}\tVAL:{vote}")
