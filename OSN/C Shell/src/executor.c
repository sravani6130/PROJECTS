#include "executor.h"
#include "builtins.h"
#include "jobs.h"
#include "redirect.h"
#include "signals.h"
#include "util.h"

#include <fcntl.h>      /* open, fcntl, F_DUPFD_CLOEXEC */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>     /* fork, pipe, dup2, execvp, setpgid, _exit */

/* ---------- helpers ---------- */

/* Rebuilds a readable command string, e.g. "cat < a.txt | wc -l". */
static char *group_to_string(const cmd_group *g)
{
    static const char *ops[] = { "<", ">", ">>" };
    size_t len = 1;

    for (int j = 0; j < g->ncmds; j++) {
        const atomic_cmd *a = &g->cmds[j];
        len += 3;                                     /* " | " */
        for (int k = 0; k < a->argc; k++)
            len += strlen(a->argv[k]) + 1;
        for (int k = 0; k < a->nredirs; k++)
            len += strlen(a->redirs[k].file) + 4;
    }

    char *s = xmalloc(len);
    s[0] = '\0';
    for (int j = 0; j < g->ncmds; j++) {
        const atomic_cmd *a = &g->cmds[j];
        if (j > 0)
            strcat(s, " | ");
        for (int k = 0; k < a->argc; k++) {
            if (k > 0)
                strcat(s, " ");
            strcat(s, a->argv[k]);
        }
        for (int k = 0; k < a->nredirs; k++) {
            strcat(s, " ");
            strcat(s, ops[a->redirs[k].type]);
            strcat(s, " ");
            strcat(s, a->redirs[k].file);
        }
    }
    return s;
}

/* ---------- built-in in the shell process (so hop can change our cwd) ---------- */

static void run_builtin_in_shell(const atomic_cmd *a)
{
    int in_fd, out_fd;
    if (redirect_open(a, &in_fd, &out_fd) != 0)
        return;

    fflush(stdout);

    /* Save the shell's own stdin/stdout so they can be restored afterwards.
     * F_DUPFD_CLOEXEC: the copies are closed automatically in any exec'd child. */
    int saved_in = -1, saved_out = -1;
    if (in_fd != -1)
        saved_in = fcntl(STDIN_FILENO, F_DUPFD_CLOEXEC, 10);
    if (out_fd != -1)
        saved_out = fcntl(STDOUT_FILENO, F_DUPFD_CLOEXEC, 10);

    redirect_apply(in_fd, out_fd);
    run_builtin(a);
    fflush(stdout);

    if (saved_in != -1) {
        dup2(saved_in, STDIN_FILENO);
        close(saved_in);
    }
    if (saved_out != -1) {
        dup2(saved_out, STDOUT_FILENO);
        close(saved_out);
    }
}

/* ---------- child side of fork() ---------- */

static void run_child(const atomic_cmd *a, int index, int ncmds,
                      int prev_read, const int pipe_fds[2],
                      pid_t pgid, int background)
{
    /* 1. Join the job's process group (pgid 0 = become leader with our own pid). */
    setpgid(0, pgid);
    if (!background && shell_is_interactive())
        tcsetpgrp(STDIN_FILENO, getpgrp());   /* SIGTTOU still ignored here */

    signals_reset_for_child();

    /* 2. Keep a copy of the real stdout for error messages after rewiring. */
    int err_out = fcntl(STDOUT_FILENO, F_DUPFD_CLOEXEC, 10);

    /* 3. Open redirection files first, while stdout is still the terminal,
     *    so error messages don't disappear into a pipe or file. */
    int in_fd, out_fd;
    if (redirect_open(a, &in_fd, &out_fd) != 0)
        _exit(1);

    /* 4. Background jobs must not read from the terminal. */
    if (background && index == 0) {
        int devnull = open("/dev/null", O_RDONLY);
        if (devnull >= 0) {
            dup2(devnull, STDIN_FILENO);
            close(devnull);
        }
    }

    /* 5. Pipe wiring: read from the previous pipe, write into the next one. */
    if (prev_read != -1) {
        dup2(prev_read, STDIN_FILENO);
        close(prev_read);
    }
    if (index < ncmds - 1) {
        dup2(pipe_fds[1], STDOUT_FILENO);
        close(pipe_fds[1]);
        close(pipe_fds[0]);
    }

    /* 6. Explicit redirections override the pipe ends. */
    redirect_apply(in_fd, out_fd);

    /* 7. Run it. */
    if (is_builtin(a->argv[0])) {
        run_builtin(a);
        fflush(stdout);
        _exit(0);
    }

    execvp(a->argv[0], a->argv);

    /* Only reached if exec failed. */
    if (err_out != -1)
        dprintf(err_out, "Command not found!\n");
    _exit(127);
}

/* ---------- parent side: launch a whole cmd_group as one job ---------- */

static void launch_group(const cmd_group *g, int background)
{
    int n = g->ncmds;
    pid_t *pids = xmalloc((size_t)n * sizeof(pid_t));
    int launched = 0;
    pid_t pgid = 0;
    int prev_read = -1;     /* read end of the pipe from the previous command */

    fflush(stdout);         /* don't let children inherit unflushed output */

    for (int i = 0; i < n; i++) {
        int pipe_fds[2] = { -1, -1 };
        if (i < n - 1 && pipe(pipe_fds) != 0) {
            perror("pipe");
            break;
        }

        pid_t pid = fork();
        if (pid < 0) {
            perror("fork");
            if (pipe_fds[0] != -1) {
                close(pipe_fds[0]);
                close(pipe_fds[1]);
            }
            break;
        }

        if (pid == 0)
            run_child(&g->cmds[i], i, n, prev_read, pipe_fds, pgid, background);

        /* parent */
        if (pgid == 0)
            pgid = pid;               /* first process leads the group */
        setpgid(pid, pgid);           /* also done in the child: avoids a race */
        pids[launched++] = pid;

        /* Close the ends the parent doesn't need, or readers never see EOF. */
        if (prev_read != -1)
            close(prev_read);
        if (i < n - 1) {
            close(pipe_fds[1]);
            prev_read = pipe_fds[0];
        } else {
            prev_read = -1;
        }
    }
    if (prev_read != -1)
        close(prev_read);

    if (launched == 0) {
        free(pids);
        return;
    }

    char *text = group_to_string(g);
    job *j = job_create(pgid, pids, launched, g->cmds[0].argv[0], text);
    free(text);
    free(pids);

    if (background) {
        jobs_add(j);
        printf("[%d] %d\n", j->id, (int)j->pgid);
        fflush(stdout);
        return;
    }

    if (job_wait_foreground(j)) {     /* Ctrl-Z: keep it as a stopped job */
        jobs_add(j);
        printf("[%d] Stopped %s\n", j->id, j->name);
        fflush(stdout);
    } else {
        job_free(j);
    }
}

/* ---------- public ---------- */

void execute_shell_cmd(const shell_cmd *cmd)
{
    /* Groups run left to right. ';' groups are waited for before the next starts;
     * '&' groups are launched and left running. A failure doesn't stop the rest. */
    for (int i = 0; i < cmd->ngroups; i++) {
        const cmd_group *g = &cmd->groups[i];

        /* A lone foreground built-in runs inside the shell itself. */
        if (!g->background && g->ncmds == 1 && is_builtin(g->cmds[0].argv[0]))
            run_builtin_in_shell(&g->cmds[0]);
        else
            launch_group(g, g->background);
    }
}
