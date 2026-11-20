#ifndef SIGNALS_H
#define SIGNALS_H

#include <sys/types.h>

/*
 * Sets up the shell's signal handling and (if stdin is a terminal) puts the
 * shell in its own process group in control of the terminal.
 *   SIGINT  (Ctrl-C) -> forwarded to the foreground job; shell keeps running
 *   SIGTSTP (Ctrl-Z) -> forwarded to the foreground job; shell is not stopped
 *   SIGTTOU / SIGTTIN -> ignored, so the shell can call tcsetpgrp safely
 */
void signals_init(void);

/* In a freshly forked child: restore default signal behaviour. */
void signals_reset_for_child(void);

/* Which process group is in the foreground right now (0 = none). */
void set_foreground_pgid(pid_t pgid);

/* 1 if stdin is a terminal (interactive use), 0 if input is piped/redirected. */
int shell_is_interactive(void);

/* Give the terminal to a job's process group / take it back for the shell. */
void terminal_give(pid_t pgid);
void terminal_take_back(void);

#endif /* SIGNALS_H */
