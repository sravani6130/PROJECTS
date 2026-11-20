#include "input.h"

#include <errno.h>      /* errno, EINTR */
#include <stdio.h>      /* getline, ferror, clearerr */
#include <stdlib.h>     /* free */
#include <sys/types.h>  /* ssize_t */

static char *line = NULL;   /* grown automatically by getline() */
static size_t cap = 0;      /* current capacity of `line` */

char *read_input(void)
{
    while (1) {
        errno = 0;
        ssize_t len = getline(&line, &cap, stdin);

        if (len == -1) {
            /*
             * getline() returns -1 both for EOF and for errors.
             * If a signal (e.g. SIGCHLD from a finished background job)
             * interrupted the read, that's not a real error: clear the
             * stream's error flag and try again.
             */
            if (ferror(stdin) && errno == EINTR) {
                clearerr(stdin);
                continue;
            }
            return NULL;   /* real EOF (Ctrl-D) or real error */
        }

        /* Strip trailing '\n' and '\r' (Windows-style "\r\n" line endings). */
        while (len > 0 && (line[len - 1] == '\n' || line[len - 1] == '\r'))
            line[--len] = '\0';

        return line;
    }
}

void input_cleanup(void)
{
    free(line);
    line = NULL;
    cap = 0;
}
