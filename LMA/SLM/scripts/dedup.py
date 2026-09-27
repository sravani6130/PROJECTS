input_file = "dogri__combined.txt"     # original file
output_file = "dogri.txt"   # file without duplicates

# Use a set to store unique lines
seen = set()
with open(input_file, "r", encoding="utf-8") as infile, \
     open(output_file, "w", encoding="utf-8") as outfile:
    for line in infile:
        # Remove trailing newline for comparison
        stripped_line = line.rstrip("\n")
        if stripped_line not in seen:
            seen.add(stripped_line)
            outfile.write(line)  # write original line with newline

print(f"Duplicate lines removed. Saved to {output_file}")
