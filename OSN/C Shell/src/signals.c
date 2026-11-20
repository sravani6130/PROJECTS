#include "signals.h"

#include <signal.h>   /* sigaction, kill */
#include <string.h>   /* memset */
#include <termios.h>  /* tcgetattr, tcsetattr */
#include <unistd.h>   /* isatty, tcsetpgrp, getpgrp, setpgid */

/* Read by the signal handler, so it must be volatile sig_atomic_t. */
static volatile sig_atomic_t fg_pgid = 0;

static int interactive = 0;
static pid_t shell_pgid = 0;
static struct termios shell_tmodes;   /* terminal settings to restore after a job */

/*
 * Ctrl-C / Ctrl-Z handler. Only async-signal-safe calls (kill) are allowed here.
 * In a terminal the kernel already sends these to the foreground job's group;
 * this forwarding covers the non-terminal case (e.g. `kill -INT <shell pid>`).
 */
static void forward_to_foreground(int sig)
{
    pid_t pg = (pid_t)fg_pgid;
    if (pg > 0)
        kill(-pg, sig);      /* negative pid = whole process group */
}

static void set_handler(int sig, void (*handler)(int))
{
    struct sigaction sa;
    memset(&sa, 0, sizeof(sa));
    sa.sa_handler = handler;
    sigemptyset(&sa.sa_mask);
    sa.sa_flags = SA_RESTART;   /* restart interrupted read()/waitpid() automatically */
    sigaction(sig, &sa, NULL);
}

void signals_init(void)
{
    interactive = isatty(STDIN_FILENO);

    if (interactive) {
        /* If we were started in the background, wait until we're in the foreground. */
        while (tcgetpgrp(STDIN_FILENO) != (shell_pgid = getpgrp()))
            kill(-shell_pgid, SIGTTIN);
    }

    set_handler(SIGINT, forward_to_foreground);
    set_handler(SIGTSTP, forward_to_foreground);
    set_handler(SIGTTOU, SIG_IGN);
    set_handler(SIGTTIN, SIG_IGN);

    if (interactive) {
        setpgid(0, 0);                       /* own process group (may already be) */
        shell_pgid = getpgrp();
        tcsetpgrp(STDIN_FILENO, shell_pgid); /* take control of the terminal */
        tcgetattr(STDIN_FILENO, &shell_tmodes);
    }
}

void signals_reset_for_child(void)
{
    /* SIG_IGN would be inherited across exec, so explicitly restore defaults. */
    signal(SIGINT, SIG_DFL);
    signal(SIGTSTP, SIG_DFL);
    signal(SIGTTOU, SIG_DFL);
    signal(SIGTTIN, SIG_DFL);
    signal(SIGQUIT, SIG_DFL);
    signal(SIGCHLD, SIG_DFL);
}

void set_foreground_pgid(pid_t pgid)
{
    fg_pgid = (sig_atomic_t)pgid;
}

int shell_is_interactive(void)
{
    return interactive;
}

void terminal_give(pid_t pgid)
{
    if (interactive)
        tcsetpgrp(STDIN_FILENO, pgid);
}

void terminal_take_back(void)
{
    if (interactive) {
        tcsetpgrp(STDIN_FILENO, shell_pgid);
        tcsetattr(STDIN_FILENO, TCSADRAIN, &shell_tmodes);  /* undo e.g. vim's raw mode */
    }
}
