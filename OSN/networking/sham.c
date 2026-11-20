#include "sham.h"

#include <arpa/inet.h>    /* htonl, ntohl, htons, ntohs */
#include <errno.h>
#include <stdarg.h>
#include <stdlib.h>
#include <string.h>
#include <sys/select.h>
#include <sys/socket.h>
#include <sys/time.h>     /* gettimeofday */
#include <time.h>
#include <unistd.h>

/* ======================================================================
 *  Small helpers
 * ====================================================================== */

long long now_ms(void)
{
    struct timeval tv;
    gettimeofday(&tv, NULL);
    return (long long)tv.tv_sec * 1000 + tv.tv_usec / 1000;
}

/* Sequence numbers wrap around at 2^32, so compare them by their difference. */
static int seq_lt(uint32_t a, uint32_t b)  { return (int32_t)(a - b) < 0; }
static int seq_leq(uint32_t a, uint32_t b) { return (int32_t)(a - b) <= 0; }

int parse_loss_rate(const char *s, double *out)
{
    char *end;
    errno = 0;
    double v = strtod(s, &end);
    if (errno != 0 || end == s || *end != '\0' || v < 0.0 || v > 1.0)
        return -1;
    *out = v;
    return 0;
}

int parse_port(const char *s, uint16_t *out)
{
    char *end;
    errno = 0;
    long v = strtol(s, &end, 10);
    if (errno != 0 || end == s || *end != '\0' || v < 1 || v > 65535)
        return -1;
    *out = (uint16_t)v;
    return 0;
}

/* ======================================================================
 *  Logging: [YYYY-MM-DD HH:MM:SS.microseconds] [LOG] <event>
 * ====================================================================== */

void sham_log_open(sham_conn *c, const char *filename)
{
    const char *env = getenv("RUDP_LOG");
    c->log = NULL;
    if (env != NULL && strcmp(env, "1") == 0) {
        c->log = fopen(filename, "w");
        if (c->log == NULL)
            perror(filename);
    }
}

void sham_log_close(sham_conn *c)
{
    if (c->log != NULL) {
        fclose(c->log);
        c->log = NULL;
    }
}

void sham_log(sham_conn *c, const char *fmt, ...)
{
    if (c->log == NULL)
        return;

    struct timeval tv;
    gettimeofday(&tv, NULL);
    time_t secs = tv.tv_sec;
    char stamp[32];
    strftime(stamp, sizeof(stamp), "%Y-%m-%d %H:%M:%S", localtime(&secs));

    fprintf(c->log, "[%s.%06ld] [LOG] ", stamp, (long)tv.tv_usec);

    va_list ap;
    va_start(ap, fmt);
    vfprintf(c->log, fmt, ap);
    va_end(ap);

    fputc('\n', c->log);
    fflush(c->log);
}

/* ======================================================================
 *  Sending and receiving single packets
 * ====================================================================== */

void sham_conn_init(sham_conn *c, int sock, double loss_rate)
{
    memset(c, 0, sizeof(*c));
    c->sock = sock;
    c->loss_rate = loss_rate;
    c->peer_window = SHAM_RECV_BUF;
}

/* Free space in our receive buffer: what we advertise as window_size. */
uint16_t sham_recv_window(const sham_conn *c)
{
    return (uint16_t)(SHAM_RECV_BUF - c->ooo_bytes);
}

/* Builds the 12-byte header in network byte order, appends the data, sends it. */
int sham_send(sham_conn *c, uint16_t flags, uint32_t seq, const void *data, size_t len)
{
    uint8_t buf[SHAM_HDR_LEN + SHAM_MSS];
    uint32_t v32;
    uint16_t v16;

    v32 = htonl(seq);                    memcpy(buf + 0,  &v32, 4);
    v32 = htonl(c->rcv_nxt);             memcpy(buf + 4,  &v32, 4);
    v16 = htons(flags);                  memcpy(buf + 8,  &v16, 2);
    v16 = htons(sham_recv_window(c));    memcpy(buf + 10, &v16, 2);
    if (len > 0)
        memcpy(buf + SHAM_HDR_LEN, data, len);

    ssize_t n = sendto(c->sock, buf, SHAM_HDR_LEN + len, 0,
                       (const struct sockaddr *)&c->peer, sizeof(c->peer));
    return n < 0 ? -1 : 0;
}

static int same_addr(const struct sockaddr_in *a, const struct sockaddr_in *b)
{
    return a->sin_addr.s_addr == b->sin_addr.s_addr && a->sin_port == b->sin_port;
}

int sham_recv(sham_conn *c, sham_packet *p, int timeout_ms)
{
    long long deadline = timeout_ms < 0 ? -1 : now_ms() + timeout_ms;

    while (1) {
        struct timeval tv, *tvp = NULL;
        if (deadline >= 0) {
            long long left = deadline - now_ms();
            if (left < 0)
                left = 0;
            tv.tv_sec = (time_t)(left / 1000);
            tv.tv_usec = (suseconds_t)((left % 1000) * 1000);
            tvp = &tv;
        }

        fd_set rfds;
        FD_ZERO(&rfds);
        FD_SET(c->sock, &rfds);
        int r = select(c->sock + 1, &rfds, NULL, NULL, tvp);
        if (r < 0) {
            if (errno == EINTR)
                continue;
            return -1;
        }
        if (r == 0)
            return 0;                                 /* timed out */

        uint8_t buf[SHAM_HDR_LEN + SHAM_MSS];
        struct sockaddr_in from;
        socklen_t fromlen = sizeof(from);
        ssize_t n = recvfrom(c->sock, buf, sizeof(buf), 0, (struct sockaddr *)&from, &fromlen);
        if (n < 0) {
            if (errno == EINTR)
                continue;
            return -1;
        }
        if (n < SHAM_HDR_LEN)
            continue;                                 /* too short to be ours */

        if (c->has_peer && !same_addr(&from, &c->peer))
            continue;                                 /* someone else: ignore */
        if (!c->has_peer)
            c->peer = from;                           /* remember who wrote first */

        uint32_t v32;
        uint16_t v16;
        memcpy(&v32, buf + 0, 4);  p->h.seq_num = ntohl(v32);
        memcpy(&v32, buf + 4, 4);  p->h.ack_num = ntohl(v32);
        memcpy(&v16, buf + 8, 2);  p->h.flags = ntohs(v16);
        memcpy(&v16, buf + 10, 2); p->h.window_size = ntohs(v16);
        p->len = (size_t)n - SHAM_HDR_LEN;
        memcpy(p->data, buf + SHAM_HDR_LEN, p->len);
        return 1;
    }
}

static uint32_t random_isn(void)
{
    return (uint32_t)rand() % 100000u + 1;
}

/* ======================================================================
 *  Three-way handshake
 *     client → SYN      seq=X
 *     server → SYN-ACK  seq=Y ack=X+1
 *     client → ACK      ack=Y+1
 * ====================================================================== */

int sham_connect(sham_conn *c)
{
    c->is_server = 0;
    c->isn = random_isn();

    for (int attempt = 0; attempt < SHAM_MAX_RETRIES; attempt++) {
        sham_send(c, SHAM_SYN, c->isn, NULL, 0);
        sham_log(c, "SND SYN SEQ=%u", c->isn);

        long long deadline = now_ms() + SHAM_TIMEOUT_MS;
        sham_packet p;
        while (now_ms() < deadline) {
            int r = sham_recv(c, &p, (int)(deadline - now_ms()));
            if (r < 0)
                return -1;
            if (r == 0)
                break;
            if ((p.h.flags & (SHAM_SYN | SHAM_ACK)) == (SHAM_SYN | SHAM_ACK) &&
                p.h.ack_num == c->isn + 1) {
                sham_log(c, "RCV SYN-ACK SEQ=%u ACK=%u", p.h.seq_num, p.h.ack_num);
                c->rcv_nxt = p.h.seq_num + 1;           /* their SYN uses one number */
                c->snd_una = c->snd_nxt = c->isn + 1;   /* our SYN uses one number */
                c->peer_window = p.h.window_size;
                sham_resend_handshake_ack(c);
                return 0;
            }
        }
    }
    return -1;   /* server never answered */
}

/* The last ACK of the handshake (also re-sent if the server repeats its SYN-ACK). */
void sham_resend_handshake_ack(sham_conn *c)
{
    sham_send(c, SHAM_ACK, c->snd_nxt, NULL, 0);
    sham_log(c, "SND ACK FOR SYN");
}

int sham_accept(sham_conn *c)
{
    sham_packet p;
    c->is_server = 1;
    c->has_peer = 0;

    /* 1. Wait for a SYN from anyone. */
    while (1) {
        int r = sham_recv(c, &p, -1);
        if (r < 0)
            return -1;
        if ((p.h.flags & SHAM_SYN) && !(p.h.flags & SHAM_ACK))
            break;
        c->has_peer = 0;              /* not a SYN: forget this sender, keep waiting */
    }
    c->has_peer = 1;                  /* lock on to this client */
    sham_log(c, "RCV SYN SEQ=%u", p.h.seq_num);

    c->rcv_nxt = p.h.seq_num + 1;
    c->peer_window = p.h.window_size;
    c->isn = random_isn();

    /* 2. Send SYN-ACK until the client's ACK (or its first data) arrives. */
    for (int attempt = 0; attempt < SHAM_MAX_RETRIES; attempt++) {
        sham_send(c, SHAM_SYN | SHAM_ACK, c->isn, NULL, 0);
        sham_log(c, "SND SYN-ACK SEQ=%u ACK=%u", c->isn, c->rcv_nxt);

        long long deadline = now_ms() + SHAM_TIMEOUT_MS;
        while (now_ms() < deadline) {
            int r = sham_recv(c, &p, (int)(deadline - now_ms()));
            if (r < 0)
                return -1;
            if (r == 0)
                break;
            if (p.h.flags & SHAM_SYN)
                break;                                 /* client repeated SYN: resend SYN-ACK */

            int acks_syn = (p.h.flags & SHAM_ACK) && p.h.ack_num == c->isn + 1;
            if (acks_syn || p.len > 0) {
                /* An ACK for our SYN, or data (meaning the ACK was lost but the client moved on). */
                sham_log(c, "RCV ACK FOR SYN");
                c->snd_una = c->snd_nxt = c->isn + 1;
                c->peer_window = p.h.window_size;
                if (p.len > 0 || (p.h.flags & SHAM_FIN)) {
                    c->pending = p;                    /* process it in the main loop */
                    c->has_pending = 1;
                }
                return 0;
            }
        }
    }
    return -1;
}

/* ======================================================================
 *  Sending data: sliding window + flow control + retransmission
 * ====================================================================== */

static int packets_in_flight(const sham_conn *c)
{
    int n = 0;
    for (int i = 0; i < SHAM_WINDOW_PKTS; i++)
        n += c->slots[i].in_use;
    return n;
}

int sham_all_acked(const sham_conn *c)
{
    return c->snd_una == c->snd_nxt;
}

int sham_pump(sham_conn *c, sham_source_fn src, void *ctx)
{
    int sent = 0;

    while (1) {
        /* Sliding window: at most SHAM_WINDOW_PKTS packets unacknowledged. */
        if (packets_in_flight(c) >= SHAM_WINDOW_PKTS)
            break;

        /* Flow control: LastByteSent - LastByteAcked <= receiver's window.
         * With nothing in flight we always allow one packet, so a tiny window
         * can never block the transfer forever. */
        uint32_t in_flight = c->snd_nxt - c->snd_una;
        if (in_flight > 0 && in_flight + SHAM_MSS > c->peer_window)
            break;

        sham_send_slot *slot = NULL;
        for (int i = 0; i < SHAM_WINDOW_PKTS; i++) {
            if (!c->slots[i].in_use) {
                slot = &c->slots[i];
                break;
            }
        }

        size_t n = src(ctx, slot->data, SHAM_MSS);
        if (n == 0)
            break;                                     /* nothing more to send right now */

        slot->in_use = 1;
        slot->seq = c->snd_nxt;
        slot->len = (uint16_t)n;
        slot->retries = 0;
        slot->sent_ms = now_ms();

        sham_send(c, 0, slot->seq, slot->data, n);
        sham_log(c, "SND DATA SEQ=%u LEN=%zu", slot->seq, n);

        c->snd_nxt += (uint32_t)n;
        sent++;
    }
    return sent;
}

void sham_on_ack(sham_conn *c, const sham_packet *p)
{
    uint32_t ack = p->h.ack_num;
    sham_log(c, "RCV ACK=%u", ack);

    if (p->h.window_size != c->peer_window) {
        c->peer_window = p->h.window_size;
        sham_log(c, "FLOW WIN UPDATE=%u", c->peer_window);
    }

    /* Cumulative ACK: everything before `ack` has arrived. */
    if (seq_lt(c->snd_una, ack) && seq_leq(ack, c->snd_nxt)) {
        for (int i = 0; i < SHAM_WINDOW_PKTS; i++) {
            sham_send_slot *s = &c->slots[i];
            if (s->in_use && seq_leq(s->seq + s->len, ack))
                s->in_use = 0;
        }
        c->snd_una = ack;
    }
}

int sham_check_timeouts(sham_conn *c)
{
    long long now = now_ms();

    /*
     * Only the OLDEST unacknowledged packet (the one starting at snd_una) can
     * time out. Packets sent after it may well have arrived and be waiting in
     * the receiver's buffer: they can't be acknowledged until the gap is
     * filled. Once the oldest one gets through, the receiver's cumulative ACK
     * covers them all, so they are never resent needlessly. If a later packet
     * really was lost, it becomes the oldest after that ACK, and since its
     * timer has usually expired by then, it is resent straight away.
     */
    sham_send_slot *oldest = NULL;
    for (int i = 0; i < SHAM_WINDOW_PKTS; i++) {
        sham_send_slot *s = &c->slots[i];
        if (s->in_use && (oldest == NULL || seq_lt(s->seq, oldest->seq)))
            oldest = s;
    }
    if (oldest == NULL || now - oldest->sent_ms < SHAM_TIMEOUT_MS)
        return 0;

    if (oldest->retries >= SHAM_MAX_RETRIES)
        return -1;                                     /* the peer seems to be gone */

    sham_log(c, "TIMEOUT SEQ=%u", oldest->seq);
    sham_send(c, 0, oldest->seq, oldest->data, oldest->len);
    sham_log(c, "RETX DATA SEQ=%u LEN=%u", oldest->seq, oldest->len);
    oldest->sent_ms = now;
    oldest->retries++;
    return 0;
}

/* ======================================================================
 *  Receiving data: in-order delivery, out-of-order buffering, ACKs
 * ====================================================================== */

static void send_ack(sham_conn *c)
{
    sham_send(c, SHAM_ACK, c->snd_nxt, NULL, 0);
    sham_log(c, "SND ACK=%u WIN=%u", c->rcv_nxt, sham_recv_window(c));
}

void sham_on_data(sham_conn *c, const sham_packet *p, sham_deliver_fn deliver, void *ctx)
{
    uint32_t seq = p->h.seq_num;

    /* Simulated packet loss: pretend this packet never arrived. */
    if (c->loss_rate > 0.0 && (double)rand() / RAND_MAX < c->loss_rate) {
        sham_log(c, "DROP DATA SEQ=%u", seq);
        return;
    }

    sham_log(c, "RCV DATA SEQ=%u LEN=%zu", seq, p->len);

    if (seq == c->rcv_nxt) {
        /* The packet we were waiting for: deliver it, then anything buffered right after it. */
        deliver(ctx, p->data, p->len);
        c->rcv_nxt += (uint32_t)p->len;

        int found = 1;
        while (found) {
            found = 0;
            for (int i = 0; i < SHAM_RECV_SLOTS; i++) {
                sham_recv_slot *s = &c->ooo[i];
                if (s->in_use && s->seq == c->rcv_nxt) {
                    deliver(ctx, s->data, s->len);
                    c->rcv_nxt += s->len;
                    c->ooo_bytes -= s->len;
                    s->in_use = 0;
                    found = 1;
                }
            }
        }
    } else if (seq_lt(c->rcv_nxt, seq)) {
        /* Arrived early: keep it if it fits and isn't already stored. */
        int duplicate = 0;
        sham_recv_slot *free_slot = NULL;
        for (int i = 0; i < SHAM_RECV_SLOTS; i++) {
            if (c->ooo[i].in_use && c->ooo[i].seq == seq)
                duplicate = 1;
            else if (!c->ooo[i].in_use && free_slot == NULL)
                free_slot = &c->ooo[i];
        }
        int fits = c->ooo_bytes + p->len <= SHAM_RECV_BUF &&
                   seq + p->len - c->rcv_nxt <= SHAM_RECV_BUF;
        if (!duplicate && free_slot != NULL && fits) {
            free_slot->in_use = 1;
            free_slot->seq = seq;
            free_slot->len = (uint16_t)p->len;
            memcpy(free_slot->data, p->data, p->len);
            c->ooo_bytes += p->len;
        }
    }
    /* else: an old duplicate we already have. Just ACK again. */

    send_ack(c);
}

int sham_handle(sham_conn *c, const sham_packet *p, sham_deliver_fn deliver, void *ctx)
{
    uint16_t f = p->h.flags;

    if (f & SHAM_FIN)
        return 1;

    if ((f & SHAM_SYN) && (f & SHAM_ACK)) {           /* server repeated SYN-ACK: our ACK was lost */
        if (!c->is_server)
            sham_resend_handshake_ack(c);
        return 0;
    }
    if (f & SHAM_SYN) {                               /* client repeated SYN */
        if (c->is_server) {
            sham_send(c, SHAM_SYN | SHAM_ACK, c->isn, NULL, 0);
            sham_log(c, "SND SYN-ACK SEQ=%u ACK=%u", c->isn, c->rcv_nxt);
        }
        return 0;
    }

    if (p->len > 0)
        sham_on_data(c, p, deliver, ctx);
    else if (f & SHAM_ACK)
        sham_on_ack(c, p);
    return 0;
}

/* ======================================================================
 *  Four-way close
 *     A → FIN,  B → ACK,  B → FIN,  A → ACK
 * ====================================================================== */

static void send_fin_ack(sham_conn *c, uint32_t their_fin)
{
    c->rcv_nxt = their_fin + 1;                       /* FIN uses one sequence number */
    sham_send(c, SHAM_ACK, c->snd_nxt, NULL, 0);
    sham_log(c, "SND ACK FOR FIN");
}

/* We start the close. Call only when all our data is acknowledged. */
int sham_close_active(sham_conn *c, sham_deliver_fn deliver, void *ctx)
{
    uint32_t fin_seq = c->snd_nxt;
    int got_ack = 0, got_fin = 0, retries = 0;
    uint32_t their_fin = 0;
    long long last_sent;

    sham_send(c, SHAM_FIN, fin_seq, NULL, 0);
    sham_log(c, "SND FIN SEQ=%u", fin_seq);
    last_sent = now_ms();

    while (!(got_ack && got_fin)) {
        if (!got_ack && now_ms() - last_sent >= SHAM_TIMEOUT_MS) {
            if (++retries > SHAM_MAX_RETRIES)
                break;                                /* peer gone: give up */
            sham_send(c, SHAM_FIN, fin_seq, NULL, 0);
            sham_log(c, "SND FIN SEQ=%u", fin_seq);
            last_sent = now_ms();
        }
        if (got_ack && now_ms() - last_sent >= SHAM_TIMEOUT_MS * SHAM_MAX_RETRIES)
            break;                                    /* peer never sent its FIN */

        sham_packet p;
        int r = sham_recv(c, &p, SHAM_TICK_MS);
        if (r < 0)
            return -1;
        if (r == 0)
            continue;

        if (p.h.flags & SHAM_FIN) {
            if (!got_fin)
                sham_log(c, "RCV FIN SEQ=%u", p.h.seq_num);
            got_fin = 1;
            their_fin = p.h.seq_num;
            if ((p.h.flags & SHAM_ACK) && p.h.ack_num == fin_seq + 1)
                got_ack = 1;
            send_fin_ack(c, their_fin);
        } else if ((p.h.flags & SHAM_ACK) && p.len == 0 && p.h.ack_num == fin_seq + 1) {
            if (!got_ack)
                sham_log(c, "RCV ACK FOR FIN");
            got_ack = 1;
        } else if (p.len > 0) {
            sham_on_data(c, &p, deliver, ctx);        /* peer still sending: keep ACKing */
        }
    }

    /* Short wait in case our last ACK was lost and the peer resends its FIN. */
    long long until = now_ms() + 2 * SHAM_TIMEOUT_MS;
    while (got_fin && now_ms() < until) {
        sham_packet p;
        int r = sham_recv(c, &p, (int)(until - now_ms()));
        if (r <= 0)
            break;
        if (p.h.flags & SHAM_FIN)
            send_fin_ack(c, their_fin);
    }

    c->snd_nxt = fin_seq + 1;
    return 0;
}

/* The peer started the close (we just received its FIN). */
int sham_close_passive(sham_conn *c, const sham_packet *fin)
{
    uint32_t their_fin = fin->h.seq_num;
    sham_log(c, "RCV FIN SEQ=%u", their_fin);
    send_fin_ack(c, their_fin);

    uint32_t my_fin = c->snd_nxt;
    for (int attempt = 0; attempt < SHAM_MAX_RETRIES; attempt++) {
        sham_send(c, SHAM_FIN | SHAM_ACK, my_fin, NULL, 0);
        sham_log(c, "SND FIN SEQ=%u", my_fin);

        long long deadline = now_ms() + SHAM_TIMEOUT_MS;
        while (now_ms() < deadline) {
            sham_packet p;
            int r = sham_recv(c, &p, (int)(deadline - now_ms()));
            if (r < 0)
                return -1;
            if (r == 0)
                break;
            if (p.h.flags & SHAM_FIN) {
                send_fin_ack(c, their_fin);           /* our ACK was lost: send it again */
            } else if ((p.h.flags & SHAM_ACK) && p.h.ack_num == my_fin + 1) {
                sham_log(c, "RCV ACK FOR FIN");
                c->snd_nxt = my_fin + 1;
                return 0;
            }
        }
    }
    return 0;   /* peer never confirmed; close anyway */
}

/* ======================================================================
 *  Chat mode: keyboard and socket at the same time, using select()
 * ====================================================================== */

#define CHAT_QUEUE 65536

typedef struct {
    uint8_t buf[CHAT_QUEUE];      /* typed text waiting to be sent */
    size_t head, tail;
} chat_queue;

static size_t chat_source(void *ctx, uint8_t *out, size_t max)
{
    chat_queue *q = ctx;
    size_t n = q->tail - q->head;
    if (n > max)
        n = max;
    memcpy(out, q->buf + q->head, n);
    q->head += n;
    if (q->head == q->tail)
        q->head = q->tail = 0;
    return n;
}

static void chat_enqueue(chat_queue *q, const char *s, size_t len)
{
    if (q->tail + len > CHAT_QUEUE) {                /* compact, then drop if still too much */
        memmove(q->buf, q->buf + q->head, q->tail - q->head);
        q->tail -= q->head;
        q->head = 0;
        if (q->tail + len > CHAT_QUEUE)
            len = CHAT_QUEUE - q->tail;
    }
    memcpy(q->buf + q->tail, s, len);
    q->tail += len;
}

static void chat_deliver(void *ctx, const uint8_t *data, size_t len)
{
    (void)ctx;
    fwrite(data, 1, len, stdout);
    fflush(stdout);
}

int sham_chat(sham_conn *c)
{
    static chat_queue q;
    char line[4096];
    size_t line_len = 0;
    int quitting = 0;

    q.head = q.tail = 0;

    if (c->has_pending) {
        c->has_pending = 0;
        if (sham_handle(c, &c->pending, chat_deliver, NULL))
            return sham_close_passive(c, &c->pending);
    }

    while (1) {
        fd_set rfds;
        FD_ZERO(&rfds);
        FD_SET(c->sock, &rfds);
        if (!quitting)
            FD_SET(STDIN_FILENO, &rfds);
        int maxfd = c->sock > STDIN_FILENO ? c->sock : STDIN_FILENO;

        struct timeval tv = { 0, SHAM_TICK_MS * 1000 };
        int r = select(maxfd + 1, &rfds, NULL, NULL, &tv);
        if (r < 0 && errno != EINTR)
            return -1;

        /* --- keyboard --- */
        if (r > 0 && !quitting && FD_ISSET(STDIN_FILENO, &rfds)) {
            char buf[1024];
            ssize_t n = read(STDIN_FILENO, buf, sizeof(buf));
            if (n <= 0) {
                quitting = 1;                         /* Ctrl-D / end of input = /quit */
            } else {
                for (ssize_t i = 0; i < n; i++) {
                    if (line_len < sizeof(line) - 1)
                        line[line_len++] = buf[i];
                    if (buf[i] != '\n')
                        continue;
                    line[line_len] = '\0';
                    if (strcmp(line, "/quit\n") == 0) {
                        quitting = 1;
                        break;
                    }
                    chat_enqueue(&q, line, line_len);
                    line_len = 0;
                }
            }
        }

        /* --- network --- */
        if (r > 0 && FD_ISSET(c->sock, &rfds)) {
            sham_packet p;
            if (sham_recv(c, &p, 0) == 1 && sham_handle(c, &p, chat_deliver, NULL))
                return sham_close_passive(c, &p);
        }

        sham_pump(c, chat_source, &q);
        if (sham_check_timeouts(c) < 0)
            return -1;

        if (quitting && q.head == q.tail && sham_all_acked(c))
            return sham_close_active(c, chat_deliver, NULL);
    }
}
