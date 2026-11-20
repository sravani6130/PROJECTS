#ifndef LOG_H
#define LOG_H

#include "parser.h"

#define HISTORY_MAX 15

/* Works out where the history file lives. Call once at startup. */
void history_init(void);

/*
 * Records an input line (exactly as typed) after it parsed successfully.
 * Skipped if any atomic command in it is named "log", or if it is identical
 * to the most recently stored command.
 */
void history_add(const char *line, const shell_cmd *cmd);

/* log | log purge | log execute <index> */
void log_command(int argc, char **argv);

#endif /* LOG_H */
