#ifndef JOBS_H
#define JOBS_H

#include <sys/types.h>

typedef enum { JOB_RUNNING, JOB_STOPPED } job_state;

/*
 * One job = one cmd_group (a single command or a pipeline), all in one
 * process group whose id is the pid of the first process.
 */
typedef struct {
    int id;            /* job number shown as [id]; 0 until added to the table */
    pid_t pgid;        /* process group id = pid of the first process */
    pid_t *pids;       /* every process in the pipeline; -1 once reaped */
    int npids;
    int alive;         /* processes not yet reaped */
    int last_status;   /* wait status of the last process in the pipeline */
    char *name;        /* command name (argv[0] of the first command) */
    char *cmdline;     /* full command text, printed by fg */
    job_state state;
} job;

job *job_create(pid_t pgid, const pid_t *pids, int npids,
                const char *name, const char *cmdline);
void job_free(job *j);

/* Table of background / stopped jobs. */
void jobs_add(job *j);          /* assigns the next job number if j->id == 0 */
void jobs_detach(job *j);       /* removes from the table without freeing */
job *jobs_find(int id);
job *jobs_most_recent(void);    /* highest job number, or NULL */
int jobs_count(void);
job *jobs_at(int index);

/*
 * Waits for a foreground job (gives it the terminal first).
 * Returns 1 if it was stopped (Ctrl-Z), 0 if all its processes finished.
 */
int job_wait_foreground(job *j);

/* Non-blocking check for finished/stopped/continued background jobs;
 * prints "<name> with pid <pid> exited normally/abnormally" for finished ones. */
void jobs_reap_background(void);

/* Sends SIGKILL to every job (used on Ctrl-D). */
void jobs_kill_all(void);

#endif /* JOBS_H */
