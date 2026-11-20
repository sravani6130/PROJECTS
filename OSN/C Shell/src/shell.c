#include "shell.h"
#include "executor.h"
#include "input.h"
#include "jobs.h"
#include "log.h"
#include "parser.h"
#include "prompt.h"
#include "signals.h"

#include <stdio.h>
#include <unistd.h>   /* isatty */

static int shell_init(void)
{
    /*
     * When input is piped in (e.g. a test script), read it one byte at a time.
     * Otherwise stdio would read ahead a whole block, swallowing lines that a
     * foreground child (like `cat`) or a later command should get.
     */
    if (!isatty(STDIN_FILENO))
        setvbuf(stdin, NULL, _IONBF, 0);

    /* Line-buffered stdout keeps our messages in order with children's output. */
    setvbuf(stdout, NULL, _IOLBF, 0);

    signals_init();
    if (prompt_init() != 0)
        return -1;
    history_init();
    return 0;
}

/* Ctrl-D: kill every child, print "logout", exit with status 0. */
static int shell_exit(void)
{
    jobs_kill_all();
    printf("logout\n");
    fflush(stdout);
    input_cleanup();
    return 0;
}

int shell_loop(void)
{
    if (shell_init() != 0)
        return 1;

    while (1) {
        prompt_display();

        char *line = read_input();
        if (line == NULL)                 /* EOF (Ctrl-D) */
            break;

        /* D.2: report finished background jobs before handling new input. */
        jobs_reap_background();

        shell_cmd cmd;
        parse_status status = parse_input(line, &cmd);

        if (status == PARSE_ERROR) {
            printf("Invalid Syntax!\n");
            continue;
        }
        if (status == PARSE_EMPTY)
            continue;

        history_add(line, &cmd);          /* B.3 */
        execute_shell_cmd(&cmd);
        free_shell_cmd(&cmd);
    }

    return shell_exit();
}
