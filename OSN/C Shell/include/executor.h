#ifndef EXECUTOR_H
#define EXECUTOR_H

#include "parser.h"

/* Runs a fully parsed input line. */
void execute_shell_cmd(const shell_cmd *cmd);

#endif /* EXECUTOR_H */
