#include "log.h"
#include "executor.h"
#include "prompt.h"   /* shell_home() */
#include "shell.h"    /* MAX_PATH_LEN, MAX_INPUT_LEN */
#include "util.h"

#include <pwd.h>      /* getpwuid */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>   /* getuid */

#define HISTORY_FILENAME ".osn_shell_history"

static char history_path[MAX_PATH_LEN];

/* In-memory copy, oldest first: entries[0] is oldest, entries[count-1] newest. */
static char *entries[HISTORY_MAX];
static int count = 0;

void history_init(void)
{
    /*
     * Use the user's real home directory (like ~/.bash_history), so the
     * history is shared no matter where the shell is started from.
     * Fall back to the shell's own home if that can't be found.
     */
    const char *dir = NULL;
    struct passwd *pw = getpwuid(getuid());
    if (pw != NULL && pw->pw_dir != NULL && pw->pw_dir[0] != '\0')
        dir = pw->pw_dir;
    else
        dir = shell_home();

    snprintf(history_path, sizeof(history_path), "%s/%s", dir, HISTORY_FILENAME);
}

static void clear_memory(void)
{
    for (int i = 0; i < count; i++)
        free(entries[i]);
    count = 0;
}

/* Appends to the in-memory list, dropping the oldest entry when full. */
static void push_entry(const char *line)
{
    if (count == HISTORY_MAX) {
        free(entries[0]);
        memmove(&entries[0], &entries[1], (HISTORY_MAX - 1) * sizeof(char *));
        count--;
    }
    entries[count++] = xstrdup(line);
}

/*
 * Reloads from the file every time, so the file is the single source of
 * truth (this also keeps things right if a child process changed it).
 */
static void load(void)
{
    clear_memory();

    FILE *f = fopen(history_path, "r");
    if (f == NULL)
        return;                         /* no history yet */

    char buf[MAX_INPUT_LEN];
    while (fgets(buf, sizeof(buf), f) != NULL) {
        buf[strcspn(buf, "\n")] = '\0';
        if (buf[0] != '\0')
            push_entry(buf);            /* keeps only the last HISTORY_MAX */
    }
    fclose(f);
}

static void save(void)
{
    FILE *f = fopen(history_path, "w");   /* "w" truncates */
    if (f == NULL)
        return;
    for (int i = 0; i < count; i++)
        fprintf(f, "%s\n", entries[i]);
    fclose(f);
}

static int contains_log(const shell_cmd *cmd)
{
    for (int i = 0; i < cmd->ngroups; i++)
        for (int j = 0; j < cmd->groups[i].ncmds; j++)
            if (strcmp(cmd->groups[i].cmds[j].argv[0], "log") == 0)
                return 1;
    return 0;
}

void history_add(const char *line, const shell_cmd *cmd)
{
    if (contains_log(cmd))
        return;

    load();
    if (count > 0 && strcmp(entries[count - 1], line) == 0)
        return;                         /* same as the previous command */

    push_entry(line);
    save();
}

static void log_execute(const char *index_str)
{
    long index;
    load();

    /* index 1 = newest command */
    if (parse_long(index_str, &index) != 0 || index < 1 || index > count) {
        printf("log: Invalid Syntax!\n");
        return;
    }

    /* Copy: executing may reload/replace the entries array. */
    char *line = xstrdup(entries[count - index]);

    shell_cmd cmd;
    if (parse_input(line, &cmd) == PARSE_OK) {
        execute_shell_cmd(&cmd);        /* not stored again */
        free_shell_cmd(&cmd);
    }
    free(line);
}

void log_command(int argc, char **argv)
{
    if (argc == 1) {                                     /* log */
        load();
        for (int i = 0; i < count; i++)
            printf("%s\n", entries[i]);
    } else if (argc == 2 && strcmp(argv[1], "purge") == 0) {
        clear_memory();
        save();
    } else if (argc == 3 && strcmp(argv[1], "execute") == 0) {
        log_execute(argv[2]);
    } else {
        printf("log: Invalid Syntax!\n");
    }
}
