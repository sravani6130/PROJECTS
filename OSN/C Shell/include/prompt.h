#ifndef PROMPT_H
#define PROMPT_H

#include <stddef.h>

/*
 * Must be called once at shell startup. Records the current working
 * directory as the shell's "home" and caches the username / hostname.
 * Returns 0 on success, -1 on failure.
 */
int prompt_init(void);

/* Prints the prompt: <username@systemname:path> */
void prompt_display(void);

/* The shell's home directory (where it was started). Needed later by hop/reveal. */
const char *shell_home(void);

/*
 * Converts an absolute path `cwd` into its display form relative to `home`:
 *   cwd == home              -> "~"
 *   cwd inside home          -> "~/rest/of/path"
 *   anything else            -> cwd unchanged (absolute path)
 * Writes the result into `out` (size `out_size`).
 */
void format_display_path(const char *cwd, const char *home, char *out, size_t out_size);

#endif /* PROMPT_H */
