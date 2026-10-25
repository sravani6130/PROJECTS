#!/usr/bin/env python3
import sys

for line in sys.stdin:
    line = line.rstrip('\n')
    if not line:
        continue

    # Strict split: doc_id<TAB>text
    parts = line.split('\t', 1)

    if len(parts) != 2:
        continue

    doc_id, content = parts

    words = content.split()
    unique_words = set(words)

    for word in unique_words:
        print(f"{word}\t1")

