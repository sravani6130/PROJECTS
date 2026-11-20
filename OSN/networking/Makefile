CC      := gcc
CFLAGS  := -std=c99 -D_POSIX_C_SOURCE=200809L -D_XOPEN_SOURCE=700 \
           -Wall -Wextra -Werror -O2
LDLIBS_SERVER := -lcrypto

.PHONY: all clean

all: server client

server: server.o sham.o md5.o
	$(CC) $(CFLAGS) -o $@ $^ $(LDLIBS_SERVER)

client: client.o sham.o
	$(CC) $(CFLAGS) -o $@ $^

%.o: %.c sham.h md5.h
	$(CC) $(CFLAGS) -c $< -o $@

clean:
	rm -f *.o server client server_log.txt client_log.txt
