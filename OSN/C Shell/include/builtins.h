#ifndef BUILTINS_H
#define BUILTINS_H

#include "parser.h"

/* Returns 1 if `name` is a command the shell implements itself. */
int is_builtin(const char *name);

/* Runs a built-in command inside the shell process. */
void run_builtin(const atomic_cmd *cmd);

#endif /* BUILTINS_H */
