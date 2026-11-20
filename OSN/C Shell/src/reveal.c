#include "reveal.h"
#include "hop.h"      /* hop_prev_dir() */
#include "prompt.h"   /* shell_home() */
#include "shell.h"    /* MAX_PATH_LEN */
#include "util.h"

#include <dirent.h>   /* opendir, readdir, closedir */
#include <stdio.h>
#include <stdlib.h>   /* qsort, free */
#include <string.h>   /* strcmp, strncmp */

/* qsort passes pointers to the array elements, i.e. char ** */
static int compare_names(const void *a, const void *b)
{
    const char *x = *(const char *const *)a;
    const char *y = *(const char *const *)b;
    return strcmp(x, y);   /* plain byte (ASCII) order: 'Z' < 'a' */
}

/*
 * Turns the target argument into a real path, using the same rules as hop.
 * Returns 0 on success, -1 if the target doesn't exist (e.g. "-" before any hop).
 */
static int resolve_target(const char *target, char *out, size_t size)
{
    if (target == NULL || strcmp(target, ".") == 0) {
        snprintf(out, size, ".");
    } else if (strcmp(target, "~") == 0) {
        snprintf(out, size, "%s", shell_home());
    } else if (strncmp(target, "~/", 2) == 0) {
        snprintf(out, size, "%s%s", shell_home(), target + 1);
    } else if (strcmp(target, "-") == 0) {
        const char *prev = hop_prev_dir();
        if (prev == NULL)
            return -1;
        snprintf(out, size, "%s", prev);
    } else {
        snprintf(out, size, "%s", target);   /* "..", relative or absolute */
    }
    return 0;
}

void reveal_command(int argc, char **argv)
{
    int show_hidden = 0;
    int one_per_line = 0;
    const char *target = NULL;

    /* ---- parse arguments ---- */
    for (int i = 1; i < argc; i++) {
        const char *arg = argv[i];

        /* A flag group: '-' followed by one or more letters. A lone "-" is a target. */
        if (arg[0] == '-' && arg[1] != '\0') {
            for (const char *c = arg + 1; *c; c++) {
                if (*c == 'a') {
                    show_hidden = 1;
                } else if (*c == 'l') {
                    one_per_line = 1;
                } else {
                    printf("reveal: Invalid Syntax!\n");   /* unknown flag */
                    return;
                }
            }
            continue;
        }

        if (target != NULL) {          /* more than one directory given */
            printf("reveal: Invalid Syntax!\n");
            return;
        }
        target = arg;
    }

    /* ---- find the directory ---- */
    char path[MAX_PATH_LEN * 2];
    if (resolve_target(target, path, sizeof(path)) != 0) {
        printf("No such directory!\n");
        return;
    }

    DIR *dir = opendir(path);
    if (dir == NULL) {                 /* missing, not a directory, or no permission */
        printf("No such directory!\n");
        return;
    }

    /* ---- collect entry names ---- */
    char **names = NULL;
    int count = 0, cap = 0;
    struct dirent *entry;

    while ((entry = readdir(dir)) != NULL) {
        if (!show_hidden && entry->d_name[0] == '.')
            continue;
        if (count == cap) {
            cap = cap ? cap * 2 : 16;
            names = xrealloc(names, (size_t)cap * sizeof(char *));
        }
        names[count++] = xstrdup(entry->d_name);
    }
    closedir(dir);

    /* ---- sort and print ---- */
    qsort(names, (size_t)count, sizeof(char *), compare_names);

    for (int i = 0; i < count; i++) {
        if (one_per_line)
            printf("%s\n", names[i]);
        else
            printf(i == 0 ? "%s" : " %s", names[i]);
    }
    if (!one_per_line && count > 0)
        printf("\n");

    for (int i = 0; i < count; i++)
        free(names[i]);
    free(names);
}
