#!/usr/bin/env python3
import sys
import math

if len(sys.argv) < 2:
    print("Usage: python reduce.py <N>", file=sys.stderr)
    sys.exit(1)

try:
    N = int(sys.argv[1])
except ValueError:
    print("Error: N must be an integer", file=sys.stderr)
    sys.exit(1)

current_word = None
current_count = 0

# Streaming Reducer
for line in sys.stdin:
    line = line.strip()
    if not line:
        continue

    word, count = line.split('\t', 1)
    
    try:
        count = int(count)
    except ValueError:
        continue

    if current_word == word:
        current_count += count
    else:
        if current_word:
            idf = math.log(N / current_count)
            print(f"{current_word}\t{idf:.4f}")
        current_word = word
        current_count = count

if current_word:
    idf = math.log(N / current_count)
    print(f"{current_word}\t{idf:.4f}")