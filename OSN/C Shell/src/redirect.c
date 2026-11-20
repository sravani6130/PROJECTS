#include "redirect.h"

#include <fcntl.h>    /* open, O_* flags */
#include <stdio.h>
#include <unistd.h>   /* dup2, close */

#define FILE_MODE 0644   /* rw-r--r-- for newly created files */

int redirect_open(const atomic_cmd *cmd, int *in_fd, int *out_fd)
{
    *in_fd = -1;
    *out_fd = -1;

    for (int i = 0; i < cmd->nredirs; i++) {
        const redirection *r = &cmd->redirs[i];

        if (r->type == REDIR_INPUT) {
            int fd = open(r->file, O_RDONLY);
            if (fd < 0) {
                printf("No such file or directory\n");
                goto fail;
            }
            if (*in_fd != -1)
                close(*in_fd);       /* an earlier '<' is overridden */
            *in_fd = fd;
        } else {
            int flags = O_WRONLY | O_CREAT |
                        (r->type == REDIR_APPEND ? O_APPEND : O_TRUNC);
            int fd = open(r->file, flags, FILE_MODE);
            if (fd < 0) {
                printf("Unable to create file for writing\n");
                goto fail;
            }
            if (*out_fd != -1)
                close(*out_fd);      /* an earlier '>' / '>>' is overridden */
            *out_fd = fd;
        }
    }
    return 0;

fail:
    fflush(stdout);
    if (*in_fd != -1)
        close(*in_fd);
    if (*out_fd != -1)
        close(*out_fd);
    *in_fd = *out_fd = -1;
    return -1;
}

void redirect_apply(int in_fd, int out_fd)
{
    if (in_fd != -1) {
        dup2(in_fd, STDIN_FILENO);
        close(in_fd);
    }
    if (out_fd != -1) {
        dup2(out_fd, STDOUT_FILENO);
        close(out_fd);
    }
}
