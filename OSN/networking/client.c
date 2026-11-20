/*
 * S.H.A.M. client
 *   File mode: ./client <server_ip> <server_port> <input_file> <output_file_name> [loss_rate]
 *   Chat mode: ./client <server_ip> <server_port> --chat [loss_rate]
 */
#include "sham.h"

#include <arpa/inet.h>
#include <netdb.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <time.h>
#include <unistd.h>

static void usage(void)
{
    fprintf(stderr,
            "Usage: ./client <server_ip> <server_port> <input_file> <output_file_name> [loss_rate]\n"
            "       ./client <server_ip> <server_port> --chat [loss_rate]\n");
    exit(1);
}

/* ---------- file mode: what gets sent ---------- */

/* Sends "<output_file_name>\n" first, then the contents of the input file. */
typedef struct {
    char header[300];
    size_t header_len, header_pos;
    FILE *in;
    int eof;
} file_source;

static size_t file_src(void *ctx, uint8_t *buf, size_t max)
{
    file_source *s = ctx;
    size_t n = 0;

    if (s->header_pos < s->header_len) {
        size_t k = s->header_len - s->header_pos;
        if (k > max)
            k = max;
        memcpy(buf, s->header + s->header_pos, k);
        s->header_pos += k;
        n += k;
    }

    if (n < max && !s->eof) {
        size_t r = fread(buf + n, 1, max - n, s->in);
        n += r;
        if (r < max - (n - r) && (feof(s->in) || ferror(s->in)))
            s->eof = 1;
    }
    return n;
}

static int source_done(const file_source *s)
{
    return s->header_pos == s->header_len && s->eof;
}

static void ignore_data(void *ctx, const uint8_t *data, size_t len)
{
    (void)ctx; (void)data; (void)len;
}

static int send_file(sham_conn *c, file_source *src)
{
    while (1) {
        sham_pump(c, file_src, src);
        if (source_done(src) && sham_all_acked(c))
            break;

        sham_packet p;
        int r = sham_recv(c, &p, SHAM_TICK_MS);
        if (r < 0)
            return -1;
        if (r == 1 && sham_handle(c, &p, ignore_data, NULL))
            return sham_close_passive(c, &p);       /* server closed early */

        if (sham_check_timeouts(c) < 0) {
            fprintf(stderr, "client: server stopped responding\n");
            return -1;
        }
    }
    return sham_close_active(c, ignore_data, NULL);
}

/* ---------- main ---------- */

static int resolve(const char *host, uint16_t port, struct sockaddr_in *out)
{
    struct addrinfo hints, *res;
    memset(&hints, 0, sizeof(hints));
    hints.ai_family = AF_INET;
    hints.ai_socktype = SOCK_DGRAM;
    if (getaddrinfo(host, NULL, &hints, &res) != 0)
        return -1;
    *out = *(struct sockaddr_in *)res->ai_addr;
    out->sin_port = htons(port);
    freeaddrinfo(res);
    return 0;
}

int main(int argc, char **argv)
{
    if (argc < 4)
        usage();

    uint16_t port;
    if (parse_port(argv[2], &port) != 0)
        usage();

    int chat = strcmp(argv[3], "--chat") == 0;
    double loss = 0.0;
    const char *input = NULL, *output = NULL;

    if (chat) {
        if (argc > 5 || (argc == 5 && parse_loss_rate(argv[4], &loss) != 0))
            usage();
    } else {
        if (argc < 5 || argc > 6 || (argc == 6 && parse_loss_rate(argv[5], &loss) != 0))
            usage();
        input = argv[3];
        output = argv[4];
        if (strchr(output, '\n') != NULL || strlen(output) >= 256) {
            fprintf(stderr, "client: invalid output file name\n");
            return 1;
        }
    }

    file_source src;
    memset(&src, 0, sizeof(src));
    if (!chat) {
        src.in = fopen(input, "rb");
        if (src.in == NULL) {
            perror(input);
            return 1;
        }
        src.header_len = (size_t)snprintf(src.header, sizeof(src.header), "%s\n", output);
    }

    srand((unsigned)time(NULL) ^ (unsigned)getpid());

    int sock = socket(AF_INET, SOCK_DGRAM, 0);
    if (sock < 0) {
        perror("socket");
        return 1;
    }

    static sham_conn c;
    sham_conn_init(&c, sock, loss);
    if (resolve(argv[1], port, &c.peer) != 0) {
        fprintf(stderr, "client: unknown host %s\n", argv[1]);
        return 1;
    }
    c.has_peer = 1;
    sham_log_open(&c, "client_log.txt");

    if (sham_connect(&c) != 0) {
        fprintf(stderr, "client: could not connect to %s:%u\n", argv[1], port);
        return 1;
    }

    int status = chat ? sham_chat(&c) : send_file(&c, &src);

    if (src.in != NULL)
        fclose(src.in);
    sham_log_close(&c);
    close(sock);
    return status == 0 ? 0 : 1;
}
