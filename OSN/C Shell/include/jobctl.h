#ifndef JOBCTL_H
#define JOBCTL_H

/* activities : list running/stopped jobs as "[pid] : name - State", sorted by name */
void activities_command(int argc, char **argv);

/* ping <pid> <signal_number> : send (signal_number % 32) to pid */
void ping_command(int argc, char **argv);

/* fg [job_number] : bring a job to the foreground (resume it if stopped) */
void fg_command(int argc, char **argv);

/* bg [job_number] : resume a stopped job in the background */
void bg_command(int argc, char **argv);

#endif /* JOBCTL_H */
