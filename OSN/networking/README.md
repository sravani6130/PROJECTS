# S.H.A.M.: Reliable File Transfer and Chat over UDP

The networking part of CS3301 Mini Project 1.

## Contents
1. [What this project does](#1-what-this-project-does)
2. [Quick start](#2-quick-start)
3. [Command syntax](#3-command-syntax)
4. [Example use cases](#4-example-use-cases)
5. [How it works](#5-how-it-works)
6. [How the code is organised](#6-how-the-code-is-organised)
7. [Reading the logs](#7-reading-the-logs)
8. [Good to know](#8-good-to-know)

---


Computers send data over a network in small pieces called **packets**. There are two common
ways to send them:

- **UDP** is fast but makes no promises. A packet can be **lost**, arrive **out of order**,
  or arrive faster than the receiver can handle, and the sender never finds out.
- **TCP** fixes all of that, but it does the work inside the operating system, so you never
  see how.

**S.H.A.M. is a small version of TCP, built by hand on top of UDP.** It takes UDP's
unreliable packets and adds the steps needed to make delivery reliable:

| Problem with UDP | What S.H.A.M. adds |
|---|---|
| No idea where a conversation starts | A **3-way handshake** to open a connection |
| Pieces can't be identified | A **sequence number** on every packet |
| The sender doesn't know what arrived | **Acknowledgements (ACKs)** from the receiver |
| Packets get lost | A **timer** that resends anything not acknowledged |
| Waiting after every packet is slow | A **sliding window**: up to 10 packets in flight |
| Packets arrive out of order | A **buffer** that holds early packets until the gap is filled |
| The receiver can be overwhelmed | **Flow control**: the receiver says how much room it has |
| No clean ending | A **4-way close** |

Two programs use it:

- **File mode:** the client sends a file and the server saves a copy. The server then prints
  the copy's **MD5 checksum**. If it matches the original's, every byte arrived correctly.
- **Chat mode:** two people type messages to each other, both at the same time.

To show that it really recovers from loss, you can make the receiver **throw away a share of
packets on purpose** (`loss_rate`).

---

## 2. Quick start

You need Linux (or WSL), `gcc`, `make`, and OpenSSL's development files (used for MD5).

```bash
sudo apt install build-essential libssl-dev     # one time only
cd networking
make                                            # builds ./server and ./client
```

Now open **two terminals** in the `networking` folder.

```bash
# Terminal 1: start the server first
./server 8080

# Terminal 2: send a file to it
echo "hello networking" > hello.txt
./client 127.0.0.1 8080 hello.txt copy.txt
```

Terminal 1 prints one line and exits:
```
MD5: 82def2228d25047a820853bf6e10123e
```
Check the copy:
```bash
md5sum hello.txt        # same hash as the server printed
cat copy.txt            # hello networking
```

`127.0.0.1` means "this computer", so both programs run on the same machine.

---

## 3. Command syntax

```
./server <port> [--chat] [loss_rate]
./client <server_ip> <server_port> <input_file> <output_file_name> [loss_rate]
./client <server_ip> <server_port> --chat [loss_rate]
```

Anything in `[ ]` is optional.

| Argument | Meaning | Example |
|---|---|---|
| `port` / `server_port` | Port number the server listens on (1–65535). Both sides must use the same one. | `8080` |
| `server_ip` | Address or hostname of the server machine | `127.0.0.1`, `192.168.1.20`, `localhost` |
| `input_file` | File on the client's side to send | `photo.jpg` |
| `output_file_name` | Name the server saves the copy under (in the folder where the server runs) | `copy.jpg` |
| `--chat` | Chat mode instead of file mode. Use it on **both** sides. | |
| `loss_rate` | Fraction of incoming **data** packets to throw away on purpose, `0.0`–`1.0`. Default `0.0`. | `0.2` (about 1 in 5) |

`loss_rate` affects only the side that **receives** data. In file mode the server receives
the data, so put the loss rate on the server. In chat mode both sides receive, so you can put
it on either side or both.

**Environment variable**

| Variable | Effect |
|---|---|
| `RUDP_LOG=1` | Write a detailed event log to `server_log.txt` / `client_log.txt` |

**What gets printed**
- The server in file mode prints exactly one line to stdout: `MD5: <32 hex characters>`.
- Errors go to stderr, for example `client: could not connect to 127.0.0.1:8080`.
- Wrong arguments print a usage message, and the program exits with status 1.

---

## 4. Example use cases

Run each example with the server in one terminal and the client in another.
**Always start the server first.**

### 4.1 Send a file and check it arrived intact
```bash
head -c 1000000 /dev/urandom > big.bin            # a 1 MB file of random bytes

./server 8080                                     # terminal 1
./client 127.0.0.1 8080 big.bin big_copy.bin      # terminal 2

md5sum big.bin big_copy.bin                       # both hashes equal the server's line
```

### 4.2 Send a file over a bad network (30% packet loss)
```bash
./server 8080 0.3                                 # terminal 1: drop ~30% of data packets
./client 127.0.0.1 8080 big.bin big_copy.bin      # terminal 2
```
The transfer takes longer, because every lost packet waits 500 ms before it is resent, but
the MD5 still matches.

### 4.3 Watch the protocol work, step by step
```bash
RUDP_LOG=1 ./server 8080 0.3                                  # terminal 1
RUDP_LOG=1 ./client 127.0.0.1 8080 hello.txt copy.txt         # terminal 2

cat client_log.txt server_log.txt
grep -c DROP server_log.txt        # how many packets the server threw away
grep -c RETX client_log.txt        # how many the client resent (the same number)
```

### 4.4 Chat between two terminals
```bash
./server 8080 --chat                     # terminal 1
./client 127.0.0.1 8080 --chat           # terminal 2
```
Type a line and press **Enter**; it appears in the other terminal. Both sides can type at any
time. Type **`/quit`** or press **Ctrl-D** to end, and both programs exit.

### 4.5 Chat over a lossy link
```bash
./server 8080 --chat 0.3                 # terminal 1
./client 127.0.0.1 8080 --chat 0.3       # terminal 2
```
Messages may take up to half a second longer, but each one arrives once, complete and in order.

### 4.6 Between two computers on the same network
```bash
# On computer A (the server), find its address:
hostname -I                               # e.g. 192.168.1.20
./server 9000

# On computer B (the client):
./client 192.168.1.20 9000 report.pdf report_copy.pdf
```
The copy is saved on computer A. A firewall must allow UDP on that port.

---

## 5. How it works

### 5.1 The packet
Every UDP packet is a **12-byte header** followed by **0–1024 bytes of data**.

```
 0       4       8     10    12                         up to 1036 bytes
 ┌───────┬───────┬─────┬─────┬───────────────────────────┐
 │  seq  │  ack  │flags│ win │  data (0–1024 bytes)      │
 └───────┴───────┴─────┴─────┴───────────────────────────┘
```

| Field | Meaning |
|---|---|
| `seq_num` | Position (byte number) of this packet's first data byte |
| `ack_num` | "The next byte I expect from you": everything before it has arrived |
| `flags` | `SYN` = 0x1 (start), `ACK` = 0x2 (acknowledgement), `FIN` = 0x4 (finish) |
| `window_size` | How many bytes of free buffer space the sender of this packet has |

The numbers are converted to network byte order with `htonl`/`htons` before sending, so
any two machines read them the same way.

### 5.2 The life of a connection

```
   CLIENT                                        SERVER
     │ ── SYN  seq=X ───────────────────────────► │   1. open
     │ ◄─ SYN-ACK  seq=Y  ack=X+1 ─────────────── │      (3-way
     │ ── ACK  ack=Y+1 ─────────────────────────► │       handshake)
     │                                            │
     │ ── DATA seq=X+1    (1024 bytes) ─────────► │   2. send data
     │ ── DATA seq=X+1025 (1024 bytes) ─────────► │      up to 10 at
     │ ── DATA ...                     ─────────► │      a time
     │ ◄─ ACK  ack=... win=... ────────────────── │
     │                                            │
     │ ── FIN ──────────────────────────────────► │   3. close
     │ ◄─ ACK ─────────────────────────────────── │      (4-way)
     │ ◄─ FIN ─────────────────────────────────── │
     │ ── ACK ──────────────────────────────────► │
```

**1. Opening (3-way handshake).** Each side picks a random starting number and tells the
other. Three messages let both sides confirm that the other side got their number. A SYN
uses up one sequence number, so data starts at `X+1`. Any handshake packet that gets lost is
sent again after 500 ms.

**2. Sending data.**
- The data is cut into pieces of at most 1024 bytes. Each piece's `seq` is the byte position
  of its first byte.
- **Sliding window:** the sender doesn't wait after every packet. Up to 10 packets can be
  unacknowledged at once, and each new ACK makes room for more.
- **Cumulative ACK:** the receiver always replies with the next byte it needs. If pieces 1, 3
  and 4 arrive, it keeps saying "I need 2".
- **Out-of-order buffer:** pieces 3 and 4 are kept, not thrown away. When 2 arrives, the
  receiver writes 2, 3 and 4 in order.
- **Retransmission:** the sender keeps a copy of every unacknowledged packet. If the
  **oldest** one gets no ACK within **500 ms**, it is resent. Later packets are not resent,
  because they are probably waiting in the receiver's buffer, and one ACK covers them all
  once the gap is filled.
- **Flow control:** the receiver's buffer holds 8192 bytes. Every packet reports how much of
  it is free (`window_size`), and the sender never has more unacknowledged bytes in flight
  than that.

**3. Closing (4-way close).** Each side says "I'm done" (FIN) and the other side
acknowledges it. FIN packets are resent until they are acknowledged.

### 5.3 Example: one lost packet
This is a real run. The client sends a 4000-byte file at 30% loss, and the first data packet
is dropped:

```
client: SND DATA SEQ=57737  ──✗  server: DROP DATA SEQ=57737      (lost)
client: SND DATA SEQ=58761  ───► server: early, kept in buffer  → ACK=57737 WIN=7168
client: SND DATA SEQ=59785  ───► server: early, kept in buffer  → ACK=57737 WIN=6144
client: SND DATA SEQ=60809  ───► server: early, kept in buffer  → ACK=57737 WIN=5207
        ... 500 ms pass with no ACK for 57737 ...
client: TIMEOUT SEQ=57737
client: RETX DATA SEQ=57737 ───► server: gap filled → writes all 4 pieces
client: RCV ACK=61746        ◄── server: ACK=61746 WIN=8192 (everything arrived)
```
One packet was lost, and only that one packet was resent.

### 5.4 How file mode sends the name
Before the file's bytes, the client sends the output name and a newline:
```
copy.txt\n<the file's bytes...>
```
The server reads up to the first `\n` to get the name, creates that file, and writes
everything after it into the file. When the connection closes, it prints the MD5 of the
saved file.

### 5.5 How chat mode listens to two things at once
In chat mode the program has to react to **the keyboard** and **the network** at the same
time. It uses `select()`, which waits on both and wakes up when either one has input, or
every 50 ms so the retransmission timers keep running. No threads are needed.

---

## 6. How the code is organised

```
 client.c / server.c        command-line handling, file reading/writing, MD5 printing
        │  gives bytes to send / receives bytes in order
        ▼
 sham.c                     the protocol itself (handshake, window, ACKs, timers, close, chat)
        │  sendto() / recvfrom()
        ▼
 UDP socket                 the operating system
```

The protocol code never touches files or the keyboard. The program using it supplies two
small functions: one that **provides** bytes to send and one that **receives** bytes as they
arrive in order. That is why file mode and chat mode share the same protocol code.

| File | What it contains |
|---|---|
| `sham.h` | The packet header, constants (1024-byte packets, 10-packet window, 500 ms timeout, 8192-byte buffer), connection state |
| `sham.c` | The whole protocol, in order: utilities, logging, sending and receiving one packet, handshake, sending data, receiving data, closing, chat mode |
| `client.c` | Reads arguments, opens the input file, connects, sends `"name\n" + file`, closes |
| `server.c` | Reads arguments, waits for a client, writes the received file, prints its MD5 |
| `md5.c`, `md5.h` | Computes a file's MD5 with OpenSSL |
| `Makefile` | `make` builds both programs; `make clean` removes binaries, `.o` files and logs |

### Main functions (in `sham.c`)

| Function | Job |
|---|---|
| `sham_send` / `sham_recv` | Build and send one packet / wait for and decode one packet (with a timeout) |
| `sham_connect` / `sham_accept` | Client / server side of the 3-way handshake |
| `sham_pump` | Send as many new packets as the window and flow control allow |
| `sham_on_ack` | Handle an ACK: free acknowledged packets, update the receiver's window |
| `sham_check_timeouts` | Resend the oldest packet if it has waited 500 ms |
| `sham_on_data` | Handle a data packet: simulate loss, buffer or deliver it, send an ACK |
| `sham_handle` | Look at any incoming packet and pass it to the right function above |
| `sham_close_active` / `sham_close_passive` | The side that starts / answers the 4-way close |
| `sham_chat` | The chat loop: keyboard and network together using `select()` |

### What happens when you run a file transfer
```
client main()                              server main()
  open file, create UDP socket               create UDP socket, bind to port
  sham_connect() ── handshake ──────────►    sham_accept()
  send_file():                               receive_file():
    loop: sham_pump → sham_recv →              loop: sham_recv → sham_handle
          sham_handle → sham_check_timeouts          → sham_on_data → write to file
  sham_close_active() ── 4-way close ───►    sham_close_passive()
  exit                                       print "MD5: ..." and exit
```

A good reading order: `sham.h`, then `sham.c` from top to bottom, then `client.c` and
`server.c`.

---

## 7. Reading the logs

Run with `RUDP_LOG=1` on either or both sides. With logging on, every event is written as
one line:
```
[2026-11-20 16:38:39.096953] [LOG] SND SYN SEQ=57736
```

| Log line | What happened |
|---|---|
| `SND SYN SEQ=` / `RCV SYN SEQ=` | Handshake started |
| `SND SYN-ACK SEQ= ACK=` / `RCV SYN-ACK SEQ= ACK=` | Server answered the handshake |
| `SND ACK FOR SYN` / `RCV ACK FOR SYN` | Handshake finished |
| `SND DATA SEQ= LEN=` / `RCV DATA SEQ= LEN=` | A data packet was sent / received |
| `SND ACK= WIN=` / `RCV ACK=` | An acknowledgement was sent / received |
| `FLOW WIN UPDATE=` | The receiver reported a different amount of free buffer space |
| `DROP DATA SEQ=` | A data packet was thrown away on purpose (`loss_rate`) |
| `TIMEOUT SEQ=` | A packet waited 500 ms without an ACK |
| `RETX DATA SEQ= LEN=` | That packet was sent again |
| `SND FIN SEQ=` / `RCV FIN SEQ=` | One side said it is finished |
| `SND ACK FOR FIN` / `RCV ACK FOR FIN` | The FIN was acknowledged |

Each new run overwrites the old log files.

---
