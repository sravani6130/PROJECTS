#include "builtins.h"
#include "hop.h"
#include "jobctl.h"
#include "log.h"
#include "reveal.h"

#include <string.h>  /* strcmp */

typedef void (*builtin_fn)(int argc, char **argv);

/* Table of built-ins: commands the shell runs itself instead of exec'ing. */
static const struct {
    const char *name;
    builtin_fn fn;
} builtins[] = {
    { "hop",        hop_command },
    { "reveal",     reveal_command },
    { "log",        log_command },
    { "activities", activities_command },
    { "ping",       ping_command },
    { "fg",         fg_command },
    { "bg",         bg_command },
};

#define NUM_BUILTINS (sizeof(builtins) / sizeof(builtins[0]))

static builtin_fn find_builtin(const char *name)
{
    for (size_t i = 0; i < NUM_BUILTINS; i++)
        if (strcmp(builtins[i].name, name) == 0)
            return builtins[i].fn;
    return NULL;
}

int is_builtin(const char *name)
{
    return find_builtin(name) != NULL;
}

void run_builtin(const atomic_cmd *cmd)
{
    builtin_fn fn = find_builtin(cmd->argv[0]);
    if (fn != NULL)
        fn(cmd->argc, cmd->argv);
}
