#include "jobs.h"
#include "signals.h"
#include "util.h"

#include <errno.h>
#include <signal.h>     /* kill, SIGINT, SIGKILL */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>   /* waitpid, W* macros */

static job **table = NULL;
static int njobs = 0;
static int cap = 0;

/* ---------- creating / freeing ---------- */

job *job_create(pid_t pgid, const pid_t *pids, int npids,
                const char *name, const char *cmdline)
{
    job *j = xmalloc(sizeof(*j));
    j->id = 0;
    j->pgid = pgid;
    j->pids = xmalloc((size_t)npids * sizeof(pid_t));
    memcpy(j->pids, pids, (size_t)npids * sizeof(pid_t));
    j->npids = npids;
    j->alive = npids;
    j->last_status = 0;
    j->name = xstrdup(name);
    j->cmdline = xstrdup(cmdline);
    j->state = JOB_RUNNING;
    return j;
}

void job_free(job *j)
{
    if (j == NULL)
        return;
    free(j->pids);
    free(j->name);
    free(j->cmdline);
    free(j);
}

/* ---------- the table ---------- */

static int next_job_id(void)
{
    int max = 0;
    for (int i = 0; i < njobs; i++)
        if (table[i]->id > max)
            max = table[i]->id;
    return max + 1;
}

void jobs_add(job *j)
{
    if (j->id == 0)
        j->id = next_job_id();
    if (njobs == cap) {
        cap = cap ? cap * 2 : 8;
        table = xrealloc(table, (size_t)cap * sizeof(job *));
    }
    table[njobs++] = j;
}

void jobs_detach(job *j)
{
    for (int i = 0; i < njobs; i++) {
        if (table[i] == j) {
            memmove(&table[i], &table[i + 1], (size_t)(njobs - i - 1) * sizeof(job *));
            njobs--;
            return;
        }
    }
}

job *jobs_find(int id)
{
    for (int i = 0; i < njobs; i++)
        if (table[i]->id == id)
            return table[i];
    return NULL;
}

job *jobs_most_recent(void)
{
    job *best = NULL;
    for (int i = 0; i < njobs; i++)
        if (best == NULL || table[i]->id > best->id)
            best = table[i];
    return best;
}

int jobs_count(void)
{
    return njobs;
}

job *jobs_at(int index)
{
    return table[index];
}

static job *find_by_pid(pid_t pid, int *idx)
{
    for (int i = 0; i < njobs; i++) {
        for (int k = 0; k < table[i]->npids; k++) {
            if (table[i]->pids[k] == pid) {
                *idx = k;
                return table[i];
            }
        }
    }
    return NULL;
}

static void mark_reaped(job *j, int idx, int status)
{
    j->pids[idx] = -1;
    j->alive--;
    if (idx == j->npids - 1)      /* a pipeline's result is its last command's */
        j->last_status = status;
}

/* ---------- waiting ---------- */

int job_wait_foreground(job *j)
{
    int stopped = 0;

    set_foreground_pgid(j->pgid);  /* so Ctrl-C / Ctrl-Z get forwarded to it */
    terminal_give(j->pgid);

    for (int i = 0; i < j->npids && !stopped; i++) {
        if (j->pids[i] == -1)
            continue;

        int status;
        pid_t r;
        do {
            r = waitpid(j->pids[i], &status, WUNTRACED);   /* also return on stop */
        } while (r == -1 && errno == EINTR);

        if (r == -1) {                 /* already gone (ECHILD) */
            mark_reaped(j, i, 0);
            continue;
        }

        if (WIFSTOPPED(status)) {
            stopped = 1;
            if (shell_is_interactive())
                printf("\n");          /* move past the echoed "^Z" */
        } else {
            mark_reaped(j, i, status);
            /* Like bash: after Ctrl-C kills a job, move to a fresh line. */
            if (WIFSIGNALED(status) && WTERMSIG(status) == SIGINT && shell_is_interactive())
                printf("\n");
        }
    }

    terminal_take_back();
    set_foreground_pgid(0);

    j->state = stopped ? JOB_STOPPED : JOB_RUNNING;
    return stopped;
}

void jobs_reap_background(void)
{
    int status;
    pid_t pid;

    /* WNOHANG: don't block. WUNTRACED/WCONTINUED: also report stop/continue. */
    while ((pid = waitpid(-1, &status, WNOHANG | WUNTRACED | WCONTINUED)) > 0) {
        int idx;
        job *j = find_by_pid(pid, &idx);
        if (j == NULL)
            continue;

        if (WIFSTOPPED(status)) {
            j->state = JOB_STOPPED;
            continue;
        }
        if (WIFCONTINUED(status)) {
            j->state = JOB_RUNNING;
            continue;
        }

        /* exited or killed by a signal */
        mark_reaped(j, idx, status);

        if (j->alive == 0) {
            int normal = WIFEXITED(j->last_status) && WEXITSTATUS(j->last_status) == 0;
            printf("%s with pid %d exited %s\n",
                   j->name, (int)j->pgid, normal ? "normally" : "abnormally");
            jobs_detach(j);
            job_free(j);
        }
    }
}

void jobs_kill_all(void)
{
    for (int i = 0; i < njobs; i++)
        kill(-table[i]->pgid, SIGKILL);
    for (int i = 0; i < njobs; i++)
        job_free(table[i]);
    free(table);
    table = NULL;
    njobs = cap = 0;
}
