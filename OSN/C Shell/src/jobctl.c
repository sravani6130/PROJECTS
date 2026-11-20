#include "jobctl.h"
#include "jobs.h"
#include "util.h"

#include <errno.h>
#include <signal.h>   /* kill, SIGCONT */
#include <stdio.h>
#include <stdlib.h>   /* qsort */
#include <string.h>

/* ---------- activities ---------- */

static int compare_jobs(const void *a, const void *b)
{
    const job *x = *(const job *const *)a;
    const job *y = *(const job *const *)b;
    int c = strcmp(x->name, y->name);
    if (c != 0)
        return c;
    return (x->pgid > y->pgid) - (x->pgid < y->pgid);   /* tie-break on pid */
}

void activities_command(int argc, char **argv)
{
    jobs_reap_background();          /* drop jobs that have already finished */

    int n = jobs_count();
    if (n == 0)
        return;

    /* Sort a copy, so job numbers / table order are unaffected. */
    job **list = xmalloc((size_t)n * sizeof(job *));
    for (int i = 0; i < n; i++)
        list[i] = jobs_at(i);
    qsort(list, (size_t)n, sizeof(job *), compare_jobs);

    for (int i = 0; i < n; i++)
        printf("[%d] : %s - %s\n", (int)list[i]->pgid, list[i]->name,
               list[i]->state == JOB_RUNNING ? "Running" : "Stopped");
    free(list);
}

/* ---------- ping ---------- */

void ping_command(int argc, char **argv)
{
    long pid, sig;

    if (argc != 3 || parse_long(argv[1], &pid) != 0 || parse_long(argv[2], &sig) != 0) {
        printf("Invalid syntax!\n");
        return;
    }

    /* pid <= 0 would mean "a whole process group" to kill(); not a process. */
    if (pid <= 0) {
        printf("No such process found\n");
        return;
    }

    int actual = (int)(((sig % 32) + 32) % 32);   /* also maps negatives into 0..31 */

    if (kill((pid_t)pid, actual) != 0) {
        printf("No such process found\n");      /* ESRCH (or EPERM) */
        return;
    }
    printf("Sent signal %ld to process with pid %ld\n", sig, pid);
}

/* ---------- fg / bg ---------- */

/* Finds the job from the optional argument; prints "No such job" if missing. */
static job *job_from_args(int argc, char **argv)
{
    if (argc > 2) {
        printf("No such job\n");
        return NULL;
    }

    job *j;
    if (argc == 1) {
        j = jobs_most_recent();
    } else {
        long id;
        j = (parse_long(argv[1], &id) == 0) ? jobs_find((int)id) : NULL;
    }

    if (j == NULL)
        printf("No such job\n");
    return j;
}

void fg_command(int argc, char **argv)
{
    jobs_reap_background();

    job *j = job_from_args(argc, argv);
    if (j == NULL)
        return;

    printf("%s\n", j->cmdline);
    fflush(stdout);

    jobs_detach(j);                    /* it's the foreground job now */

    if (j->state == JOB_STOPPED)
        kill(-j->pgid, SIGCONT);
    j->state = JOB_RUNNING;

    if (job_wait_foreground(j)) {      /* stopped again with Ctrl-Z */
        jobs_add(j);                   /* keeps its job number */
        printf("[%d] Stopped %s\n", j->id, j->name);
    } else {
        job_free(j);
    }
}

void bg_command(int argc, char **argv)
{
    jobs_reap_background();

    job *j = job_from_args(argc, argv);
    if (j == NULL)
        return;

    if (j->state == JOB_RUNNING) {
        printf("Job already running\n");
        return;
    }

    if (kill(-j->pgid, SIGCONT) != 0 && errno == ESRCH) {
        printf("No such job\n");
        return;
    }
    j->state = JOB_RUNNING;
    printf("[%d] %s &\n", j->id, j->name);
}
