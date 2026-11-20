/*
 * S.H.A.M. server
 *   ./server <port> [--chat] [loss_rate]
 *
 * File mode: receives one file, saves it under the name the client sends,
 *            and after the connection closes prints  MD5: <hex>
 * Chat mode: two-way chat until either side types /quit
 */
#include "sham.h"
#include "md5.h"

#include <arpa/inet.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <time.h>
#include <unistd.h>

#define IDLE_LIMIT_MS 30000   /* file mode: give up if the client goes silent this long */

static void usage(void)
{
    fprintf(stderr, "Usage: ./server <port> [--chat] [loss_rate]\n");
    exit(1);
}

/* ---------- file mode: where received bytes go ---------- */

/*
 * The byte stream from the client is:  <output_file_name>\n<file contents>
 * The first line names the file; everything after it is written into that file.
 */
typedef struct {
    char name[256];
    size_t name_len;
    int have_name;
    FILE *out;
} file_sink;

static void file_deliver(void *ctx, const uint8_t *data, size_t len)
{
    file_sink *s = ctx;
    size_t i = 0;

    while (!s->have_name && i < len) {
        char ch = (char)data[i++];
        if (ch == '\n') {
            s->name[s->name_len] = '\0';
            s->have_name = 1;
            s->out = fopen(s->name, "wb");
            if (s->out == NULL)
                perror(s->name);
        } else if (s->name_len < sizeof(s->name) - 1) {
            s->name[s->name_len++] = ch;
        }
    }

    if (s->have_name && s->out != NULL && i < len)
        fwrite(data + i, 1, len - i, s->out);
}

static int receive_file(sham_conn *c, file_sink *sink)
{
    long long last_heard = now_ms();

    if (c->has_pending) {
        c->has_pending = 0;
        if (sham_handle(c, &c->pending, file_deliver, sink))
            return sham_close_passive(c, &c->pending);
    }

    while (1) {
        sham_packet p;
        int r = sham_recv(c, &p, SHAM_TICK_MS);
        if (r < 0)
            return -1;
        if (r == 0) {
            if (now_ms() - last_heard > IDLE_LIMIT_MS) {
                fprintf(stderr, "server: client stopped responding\n");
                return -1;
            }
            continue;
        }
        last_heard = now_ms();
        if (sham_handle(c, &p, file_deliver, sink))
            return sham_close_passive(c, &p);       /* client finished: FIN */
    }
}

int main(int argc, char **argv)
{
    if (argc < 2 || argc > 4)
        usage();

    uint16_t port;
    if (parse_port(argv[1], &port) != 0)
        usage();

    int chat = 0;
    double loss = 0.0;
    for (int i = 2; i < argc; i++) {
        if (strcmp(argv[i], "--chat") == 0)
            chat = 1;
        else if (parse_loss_rate(argv[i], &loss) != 0)
            usage();
    }

    srand((unsigned)time(NULL) ^ (unsigned)getpid());

    int sock = socket(AF_INET, SOCK_DGRAM, 0);
    if (sock < 0) {
        perror("socket");
        return 1;
    }
    int yes = 1;
    setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, &yes, sizeof(yes));

    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = htonl(INADDR_ANY);
    addr.sin_port = htons(port);
    if (bind(sock, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
        perror("bind");
        return 1;
    }

    static sham_conn c;
    sham_conn_init(&c, sock, loss);
    sham_log_open(&c, "server_log.txt");

    if (sham_accept(&c) != 0) {
        fprintf(stderr, "server: handshake failed\n");
        return 1;
    }

    int status = 0;
    if (chat) {
        status = sham_chat(&c) == 0 ? 0 : 1;
    } else {
        file_sink sink;
        memset(&sink, 0, sizeof(sink));
        if (receive_file(&c, &sink) != 0)
            status = 1;
        if (sink.out != NULL)
            fclose(sink.out);

        char hex[33];
        if (sink.have_name && md5_file(sink.name, hex) == 0)
            printf("MD5: %s\n", hex);
        else
            status = 1;
    }

    sham_log_close(&c);
    close(sock);
    return status;
}
