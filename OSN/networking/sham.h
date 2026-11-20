#ifndef SHAM_H
#define SHAM_H

/*
 * S.H.A.M. — a small reliable transport protocol on top of UDP.
 *
 * Every UDP datagram = 12-byte header + up to SHAM_MSS bytes of data.
 * Sequence numbers count bytes. SYN and FIN each use up one sequence number.
 */

#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <netinet/in.h>

/* ---------- protocol constants ---------- */

#define SHAM_SYN 0x1
#define SHAM_ACK 0x2
#define SHAM_FIN 0x4

#define SHAM_HDR_LEN      12      /* bytes on the wire */
#define SHAM_MSS          1024    /* max data bytes per packet */
#define SHAM_WINDOW_PKTS  10      /* sender: max unacknowledged packets */
#define SHAM_RECV_BUF     8192    /* receiver buffer for out-of-order data (bytes) */
#define SHAM_RECV_SLOTS   (SHAM_RECV_BUF / SHAM_MSS)
#define SHAM_TIMEOUT_MS   500     /* retransmission timeout per packet */
#define SHAM_MAX_RETRIES  20      /* give up on a packet after this many resends */
#define SHAM_TICK_MS      50      /* how often the event loops wake up */

/* ---------- packet ---------- */

/* The header, in host byte order. It is converted to network order on send. */
struct sham_header {
    uint32_t seq_num;      /* byte offset of the first data byte */
    uint32_t ack_num;      /* next byte expected (cumulative) */
    uint16_t flags;        /* SHAM_SYN | SHAM_ACK | SHAM_FIN */
    uint16_t window_size;  /* sender's free receive buffer space, in bytes */
};

typedef struct {
    struct sham_header h;
    size_t len;                     /* number of data bytes */
    uint8_t data[SHAM_MSS];
} sham_packet;

/* ---------- connection state ---------- */

/* A packet that has been sent but not acknowledged yet. */
typedef struct {
    int in_use;
    uint32_t seq;
    uint16_t len;
    long long sent_ms;              /* when it was last (re)sent */
    int retries;
    uint8_t data[SHAM_MSS];
} sham_send_slot;

/* A packet that arrived early (out of order) and is waiting for the gap to fill. */
typedef struct {
    int in_use;
    uint32_t seq;
    uint16_t len;
    uint8_t data[SHAM_MSS];
} sham_recv_slot;

typedef struct {
    int sock;
    struct sockaddr_in peer;
    int has_peer;
    double loss_rate;               /* probability of dropping an incoming data packet */
    FILE *log;                      /* NULL unless RUDP_LOG=1 */

    /* sending side */
    uint32_t snd_una;               /* oldest unacknowledged byte */
    uint32_t snd_nxt;               /* next byte to send */
    uint32_t peer_window;           /* last window advertised by the peer */
    sham_send_slot slots[SHAM_WINDOW_PKTS];

    /* receiving side */
    uint32_t rcv_nxt;               /* next byte we expect */
    sham_recv_slot ooo[SHAM_RECV_SLOTS];
    size_t ooo_bytes;               /* bytes held in the out-of-order buffer */

    uint32_t isn;                   /* our initial sequence number (for resending SYN / SYN-ACK) */
    int is_server;

    /* a packet received during the handshake that still needs processing */
    int has_pending;
    sham_packet pending;
} sham_conn;

/* Application callbacks */
typedef size_t (*sham_source_fn)(void *ctx, uint8_t *buf, size_t max);       /* give bytes to send */
typedef void   (*sham_deliver_fn)(void *ctx, const uint8_t *data, size_t len); /* in-order bytes received */

/* ---------- utilities ---------- */

long long now_ms(void);
int  parse_loss_rate(const char *s, double *out);
int  parse_port(const char *s, uint16_t *out);

/* ---------- logging (only when RUDP_LOG=1) ---------- */

void sham_log_open(sham_conn *c, const char *filename);
void sham_log_close(sham_conn *c);
void sham_log(sham_conn *c, const char *fmt, ...) __attribute__((format(printf, 2, 3)));

/* ---------- packets ---------- */

void sham_conn_init(sham_conn *c, int sock, double loss_rate);
int  sham_send(sham_conn *c, uint16_t flags, uint32_t seq, const void *data, size_t len);
/* 1 = got a packet, 0 = timed out, -1 = error. timeout_ms < 0 waits forever. */
int  sham_recv(sham_conn *c, sham_packet *p, int timeout_ms);
uint16_t sham_recv_window(const sham_conn *c);

/* ---------- connection setup ---------- */

int sham_connect(sham_conn *c);   /* client: three-way handshake */
int sham_accept(sham_conn *c);    /* server: wait for a client and finish the handshake */
void sham_resend_handshake_ack(sham_conn *c);

/* ---------- sending ---------- */

int  sham_pump(sham_conn *c, sham_source_fn src, void *ctx);  /* send new data the windows allow */
void sham_on_ack(sham_conn *c, const sham_packet *p);
int  sham_check_timeouts(sham_conn *c);                       /* -1 if a packet gave up */
int  sham_all_acked(const sham_conn *c);

/* ---------- receiving ---------- */

void sham_on_data(sham_conn *c, const sham_packet *p, sham_deliver_fn deliver, void *ctx);

/*
 * Handles any packet that arrives after the handshake: data, ACKs, repeated
 * handshake packets. Returns 1 if it was a FIN (the caller then closes), else 0.
 */
int sham_handle(sham_conn *c, const sham_packet *p, sham_deliver_fn deliver, void *ctx);

/* ---------- connection teardown ---------- */

int sham_close_active(sham_conn *c, sham_deliver_fn deliver, void *ctx);
int sham_close_passive(sham_conn *c, const sham_packet *fin);

/* ---------- chat mode ---------- */

int sham_chat(sham_conn *c);

#endif /* SHAM_H */
