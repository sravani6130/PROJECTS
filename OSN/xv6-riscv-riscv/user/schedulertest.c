// schedulertest: standard workload for comparing schedulers.
//
// Forks NFORK children: the first IO of them are I/O-bound (they just
// sleep), the rest are CPU-bound (busy loop). The parent reaps each one
// with waitx() and prints the average running time and waiting time.
//
// Run on one CPU:  make clean; make qemu CPUS=1 SCHEDULER=<RR|FCFS|CFS>

#include "kernel/types.h"
#include "kernel/stat.h"
#include "user/user.h"
#include "kernel/fcntl.h"

#define NFORK 10
#define IO 5

int
main()
{
  int n, pid;
  int wtime, rtime;
  int twtime = 0, trtime = 0;
  for (n = 0; n < NFORK; n++) {
    pid = fork();
    if (pid < 0)
      break;
    if (pid == 0) {
      if (n < IO) {
        sleep(200); // IO bound processes
      } else {
        for (volatile int i = 0; i < 1000000000; i++) {
        } // CPU bound process
      }
      // printf("Process %d finished\n", n);
      exit(0);
    }
  }
  for (; n > 0; n--) {
    if (waitx(0, &wtime, &rtime) >= 0) {
      trtime += rtime;
      twtime += wtime;
    }
  }
  printf("Average rtime %d,  wait time %d\n", trtime / NFORK, twtime / NFORK);
  exit(0);
}
