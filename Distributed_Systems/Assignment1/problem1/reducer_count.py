#!/usr/bin/env python3
import sys

current_count = 0
current_word = None

for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
        
    try:
        word, count = line.split('\t', 1)
        count = int(count)
    except ValueError:
        continue

    if current_word == word:
        current_count += count
    else:
        if current_word:
            print(f"{current_word}\t{current_count}")
        current_word = word
        current_count = count

if current_word:
    print(f"{current_word}\t{current_count}")