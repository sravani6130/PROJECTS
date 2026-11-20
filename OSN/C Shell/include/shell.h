#ifndef SHELL_H
#define SHELL_H

/* Common limits and shared declarations for the whole shell. */

#define MAX_PATH_LEN   4096
#define MAX_INPUT_LEN  4096

/* Main read-parse-execute loop. Returns the shell's exit status. */
int shell_loop(void);

#endif /* SHELL_H */
