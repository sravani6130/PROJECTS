CC = gcc
CFLAGS = -Wall -Wextra -O2

TARGETS = part2 writer

all: $(TARGETS)

part2: part2.c
	$(CC) $(CFLAGS) -o part2 part2.c

writer: writer.c
	$(CC) $(CFLAGS) -o writer writer.c

clean:
	rm -f $(TARGETS) newfile.txt

.PHONY: all clean

