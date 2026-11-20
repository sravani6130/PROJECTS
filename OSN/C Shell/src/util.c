#include "util.h"

#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static void out_of_memory(void)
{
    perror("shell: out of memory");
    exit(EXIT_FAILURE);
}

void *xmalloc(size_t size)
{
    void *p = malloc(size);
    if (p == NULL)
        out_of_memory();
    return p;
}

void *xrealloc(void *ptr, size_t size)
{
    void *p = realloc(ptr, size);
    if (p == NULL)
        out_of_memory();
    return p;
}

char *xstrdup(const char *s)
{
    char *p = strdup(s);
    if (p == NULL)
        out_of_memory();
    return p;
}

char *xstrndup(const char *s, size_t n)
{
    char *p = strndup(s, n);
    if (p == NULL)
        out_of_memory();
    return p;
}

int parse_long(const char *s, long *out)
{
    if (s == NULL || *s == '\0')
        return -1;

    char *end;
    errno = 0;
    long v = strtol(s, &end, 10);

    if (errno == ERANGE || *end != '\0')   /* overflow or trailing junk */
        return -1;

    *out = v;
    return 0;
}
