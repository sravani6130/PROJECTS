#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <sys/types.h>

static void output_str(const char *str) {
    const char * volatile fmt = "%s";
    printf(fmt, str);
    fflush(stdout);
}


static void output_line(const char *str) {
    const char * volatile fmt = "%s\n";
    printf(fmt, str);
    fflush(stdout);
}


static char *fetch_line_dynamic(void) {
    int cap = 128;
    int len = 0;
    char *buf = (char *)malloc(cap);
    if (!buf) {
        return NULL;
    }

    char ch;
    while (scanf("%c", &ch) == 1) {
        if (ch == '\r') {
            continue;
        }
        if (ch == '\n') {
            buf[len] = '\0';
            return buf;
        }
        if (len + 1 >= cap) {
            cap *= 2;
            char *new_buf = (char *)realloc(buf, cap);
            if (!new_buf) {
                free(buf);
                return NULL;
            }
            buf = new_buf;
        }
        buf[len++] = ch;
    }

    if (len > 0) {
        buf[len] = '\0';
        return buf;
    }

    free(buf);
    return NULL;
}

/*
 * Appends a string to the specified file using file descriptor redirection
 * and printf as the only output function.
 */
static void append_to_file(const char *filepath, const char *str) {
    fflush(stdout);
    int saved_stdout = dup(STDOUT_FILENO);
    int fd = open(filepath, O_WRONLY | O_CREAT | O_APPEND, 0644);
    if (fd >= 0) {
        dup2(fd, STDOUT_FILENO);
        close(fd);
        output_line(str);
        dup2(saved_stdout, STDOUT_FILENO);
    }
    close(saved_stdout);
}


static int fetch_all_lines(const char *filepath, char ***out_lines) {
    fflush(stdout);
    clearerr(stdin);
    int saved_stdin = dup(STDIN_FILENO);
    int fd = open(filepath, O_RDONLY);
    if (fd < 0) {
        close(saved_stdin);
        *out_lines = NULL;
        return 0;
    }

    dup2(fd, STDIN_FILENO);
    close(fd);
    clearerr(stdin);

    char **lines = NULL;
    int count = 0;
    int capacity = 0;

    char *line;
    while ((line = fetch_line_dynamic()) != NULL) {
        if (count >= capacity) {
            capacity = (capacity == 0) ? 16 : capacity * 2;
            char **new_lines = (char **)realloc(lines, capacity * sizeof(char *));
            if (!new_lines) {
                free(line);
                break;
            }
            lines = new_lines;
        }
        lines[count++] = line;
    }

    clearerr(stdin);
    dup2(saved_stdin, STDIN_FILENO);
    close(saved_stdin);
    clearerr(stdin);

    *out_lines = lines;
    return count;
}


static void free_line_list(char **lines, int count) {
    if (!lines) {
        return;
    }
    for (int i = 0; i < count; i++) {
        free(lines[i]);
    }
    free(lines);
}

/*
 * Validates and parses commands formatted as "<KEYWORD> <n>".
 * Returns 1 if valid, 0 otherwise.
 */
static int parse_cmd_arg(const char *cmd, const char *keyword, int *out_val) {
    size_t klen = strlen(keyword);
    if (strncmp(cmd, keyword, klen) != 0) {
        return 0;
    }
    if (cmd[klen] != ' ') {
        return 0;
    }

    const char *p = cmd + klen + 1;
    while (*p == ' ') {
        p++;
    }
    if (*p < '0' || *p > '9') {
        return 0;
    }

    long val = 0;
    while (*p >= '0' && *p <= '9') {
        val = val * 10 + (*p - '0');
        if (val > 100000000) {
            val = 100000000;
        }
        p++;
    }
    while (*p == ' ') {
        p++;
    }
    if (*p != '\0') {
        return 0;
    }

    *out_val = (int)val;
    return 1;
}

int main(void) {
    /* Disable buffering so switching file descriptors with dup2 does not affect streams */
    setvbuf(stdin, NULL, _IONBF, 0);
    setvbuf(stdout, NULL, _IONBF, 0);

    pid_t pid = getpid();
    char dir_name[128];
    sprintf(dir_name, "folder_%d", (int)pid);
    mkdir(dir_name, 0777);

    char content_path[256];
    char logs_path[256];
    sprintf(content_path, "%s/content.txt", dir_name);
    sprintf(logs_path, "%s/logs.txt", dir_name);

    int fd_content = open(content_path, O_CREAT | O_WRONLY | O_TRUNC, 0644);
    if (fd_content >= 0) {
        close(fd_content);
    }
    int fd_logs = open(logs_path, O_CREAT | O_WRONLY | O_TRUNC, 0644);
    if (fd_logs >= 0) {
        close(fd_logs);
    }

    while (1) {
        output_str("Enter command:");
        char *cmd = fetch_line_dynamic();
        if (!cmd) {
            break;
        }

        if (strcmp(cmd, "INPUT") == 0) {
            output_str("INPUT -> ");
            char *line = fetch_line_dynamic();
            if (line) {
                append_to_file(content_path, line);
                append_to_file(logs_path, "INPUT");
                free(line);
            }
        } else if (strcmp(cmd, "PRINT") == 0) {
            append_to_file(logs_path, "PRINT");
            char **lines = NULL;
            int total = fetch_all_lines(content_path, &lines);
            for (int i = 0; i < total; i++) {
                output_line(lines[i]);
            }
            free_line_list(lines, total);
        } else if (strncmp(cmd, "FIRST", 5) == 0 && (cmd[5] == ' ' || cmd[5] == '\0')) {
            int n;
            if (parse_cmd_arg(cmd, "FIRST", &n)) {
                char log_buf[64];
                sprintf(log_buf, "FIRST %d", n);
                append_to_file(logs_path, log_buf);

                char **lines = NULL;
                int total = fetch_all_lines(content_path, &lines);
                int print_cnt = (n < total) ? n : total;
                if (print_cnt < 0) {
                    print_cnt = 0;
                }
                for (int i = 0; i < print_cnt; i++) {
                    output_line(lines[i]);
                }
                free_line_list(lines, total);
            } else {
                output_line("Unknown command..");
            }
        } else if (strncmp(cmd, "LAST", 4) == 0 && (cmd[4] == ' ' || cmd[4] == '\0')) {
            int n;
            if (parse_cmd_arg(cmd, "LAST", &n)) {
                char log_buf[64];
                sprintf(log_buf, "LAST %d", n);
                append_to_file(logs_path, log_buf);

                char **lines = NULL;
                int total = fetch_all_lines(content_path, &lines);
                int start = total - n;
                if (start < 0) {
                    start = 0;
                }
                for (int i = start; i < total; i++) {
                    output_line(lines[i]);
                }
                free_line_list(lines, total);
            } else {
                output_line("Unknown command..");
            }
        } else if (strncmp(cmd, "LOG", 3) == 0 && (cmd[3] == ' ' || cmd[3] == '\0')) {
            int n;
            if (parse_cmd_arg(cmd, "LOG", &n)) {
                char **lines = NULL;
                int total = fetch_all_lines(logs_path, &lines);
                int start = total - n;
                if (start < 0) {
                    start = 0;
                }
                for (int i = start; i < total; i++) {
                    output_line(lines[i]);
                }
                free_line_list(lines, total);
            } else {
                output_line("Unknown command..");
            }
        } else if (strcmp(cmd, "STOP") == 0) {
            append_to_file(logs_path, "STOP");
            free(cmd);
            break;
        } else {
            output_line("Unknown command..");
        }

        free(cmd);
    }

    return 0;
}

