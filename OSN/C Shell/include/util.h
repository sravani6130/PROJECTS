#ifndef UTIL_H
#define UTIL_H

#include <stddef.h>

/*
 * Allocation wrappers: same as malloc/realloc/strdup/strndup, but they
 * print an error and exit if memory runs out, so callers never get NULL.
 */
void *xmalloc(size_t size);
void *xrealloc(void *ptr, size_t size);
char *xstrdup(const char *s);
char *xstrndup(const char *s, size_t n);

/*
 * Parses a whole string as a base-10 integer (optional leading sign).
 * Returns 0 and stores the value in *out on success; returns -1 if the
 * string is empty, has trailing junk ("12ab"), or overflows.
 */
int parse_long(const char *s, long *out);

#endif /* UTIL_H */
