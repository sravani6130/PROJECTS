#!/usr/bin/env python3
import sys
import random

def gen_graph(num_nodes, filename):
    print(f"Generating {num_nodes} nodes into {filename}...")
    with open(filename, 'w') as f:
        for i in range(num_nodes):
            # Each node links to random 5-15 other nodes
            out_degree = random.randint(5, 15)
            neighbors = [str(random.randint(0, num_nodes-1)) for _ in range(out_degree)]
            # Filter self-loops
            neighbors = [n for n in neighbors if n != str(i)]
            
            # Format: node_id <TAB> neighbor,neighbor...
            line = f"{i}\t{','.join(neighbors)}\n"
            f.write(line)

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python3 gen_graph.py <num_nodes> <output_file>")
        sys.exit(1)
    
    gen_graph(int(sys.argv[1]), sys.argv[2])
