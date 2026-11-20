#include "hop.h"
#include "prompt.h"   /* shell_home() */
#include "shell.h"    /* MAX_PATH_LEN */

#include <stdio.h>    /* printf, snprintf */
#include <string.h>   /* strcmp, strncmp */
#include <unistd.h>   /* chdir, getcwd */

static char prev_dir[MAX_PATH_LEN];  /* where we were before the last move */
static int  has_prev = 0;            /* 0 until the first successful move */

const char *hop_prev_dir(void)
{
    return has_prev ? prev_dir : NULL;
}

/* Applies one hop argument. */
static void hop_step(const char *arg)
{
    char target[MAX_PATH_LEN * 2];

    /* ---- 1. work out the target directory ---- */
    if (strcmp(arg, "~") == 0) {
        snprintf(target, sizeof(target), "%s", shell_home());
    } else if (strncmp(arg, "~/", 2) == 0) {
        /* ~/src -> <home>/src */
        snprintf(target, sizeof(target), "%s%s", shell_home(), arg + 1);
    } else if (strcmp(arg, ".") == 0) {
        return;                                  /* stay put */
    } else if (strcmp(arg, "-") == 0) {
        if (!has_prev)
            return;                              /* no previous directory yet */
        snprintf(target, sizeof(target), "%s", prev_dir);
    } else {
        /* "..", relative or absolute path: the kernel resolves it */
        snprintf(target, sizeof(target), "%s", arg);
    }

    /* ---- 2. remember where we are, for `-` ---- */
    char here[MAX_PATH_LEN];
    int have_here = (getcwd(here, sizeof(here)) != NULL);

    /* ---- 3. ".." at "/" has no parent: do nothing ---- */
    if (have_here && strcmp(arg, "..") == 0 && strcmp(here, "/") == 0)
        return;

    /* ---- 4. move ---- */
    if (chdir(target) != 0) {
        /* ENOENT, ENOTDIR, EACCES ... all report the same message */
        printf("No such directory!\n");
        return;                                  /* didn't move: prev unchanged */
    }

    /* ---- 5. update prev only after a successful move ---- */
    if (have_here) {
        snprintf(prev_dir, sizeof(prev_dir), "%s", here);
        has_prev = 1;
    }
}

void hop_command(int argc, char **argv)
{
    if (argc == 1) {            /* plain "hop" means "hop ~" */
        hop_step("~");
        return;
    }

    for (int i = 1; i < argc; i++)   /* left to right; an error doesn't stop the rest */
        hop_step(argv[i]);
}
