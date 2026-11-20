#include "prompt.h"
#include "shell.h"

#include <pwd.h>        /* getpwuid, struct passwd */
#include <stdio.h>      /* printf, snprintf, fflush */
#include <stdlib.h>     /* getenv */
#include <string.h>     /* strcmp, strncmp, strlen, strchr */
#include <unistd.h>     /* getcwd, getuid, gethostname */

#define MAX_NAME_LEN 256

static char home_dir[MAX_PATH_LEN];   /* directory the shell was started in */
static char username[MAX_NAME_LEN];
static char hostname[MAX_NAME_LEN];
static char last_cwd[MAX_PATH_LEN];   /* last cwd we could read, as a fallback */

/* Username: look up the real user ID in the password database. */
static void load_username(void)
{
    struct passwd *pw = getpwuid(getuid());
    if (pw != NULL && pw->pw_name != NULL) {
        snprintf(username, sizeof(username), "%s", pw->pw_name);
        return;
    }
    /* Fallback if the passwd lookup fails. */
    const char *env = getenv("USER");
    snprintf(username, sizeof(username), "%s", env ? env : "user");
}

/* System name: like bash's \h, show the hostname up to the first '.'. */
static void load_hostname(void)
{
    if (gethostname(hostname, sizeof(hostname)) != 0) {
        snprintf(hostname, sizeof(hostname), "%s", "localhost");
        return;
    }
    hostname[sizeof(hostname) - 1] = '\0';  /* gethostname may not terminate on truncation */

    char *dot = strchr(hostname, '.');
    if (dot != NULL)
        *dot = '\0';
}

int prompt_init(void)
{
    if (getcwd(home_dir, sizeof(home_dir)) == NULL) {
        perror("getcwd");
        return -1;
    }
    snprintf(last_cwd, sizeof(last_cwd), "%s", home_dir);
    load_username();
    load_hostname();
    return 0;
}

const char *shell_home(void)
{
    return home_dir;
}

void format_display_path(const char *cwd, const char *home, char *out, size_t out_size)
{
    size_t home_len = strlen(home);

    /* Exactly home -> "~" */
    if (strcmp(cwd, home) == 0) {
        snprintf(out, out_size, "~");
        return;
    }

    /* Special case: home is "/" — every absolute path is inside it. */
    if (strcmp(home, "/") == 0) {
        snprintf(out, out_size, "~%s", cwd);
        return;
    }

    /*
     * Inside home: cwd must start with home AND the next character must be '/'.
     * The '/' check stops "/home/rudy2" from being treated as inside "/home/rudy".
     */
    if (strncmp(cwd, home, home_len) == 0 && cwd[home_len] == '/') {
        snprintf(out, out_size, "~%s", cwd + home_len);
        return;
    }

    /* Outside home -> absolute path */
    snprintf(out, out_size, "%s", cwd);
}

void prompt_display(void)
{
    char cwd[MAX_PATH_LEN];
    char display[MAX_PATH_LEN + 1];

    if (getcwd(cwd, sizeof(cwd)) != NULL)
        snprintf(last_cwd, sizeof(last_cwd), "%s", cwd);
    /* else: cwd was deleted / unreadable — reuse the last known path */

    format_display_path(last_cwd, home_dir, display, sizeof(display));

    printf("<%s@%s:%s> ", username, hostname, display);
    fflush(stdout);   /* no '\n' at the end, so flush explicitly */
}
