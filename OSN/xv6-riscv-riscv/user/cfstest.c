// cfstest: CPU-bound children with different nice values.
//
//   make clean; make qemu CPUS=1 SCHEDULER=CFS CFSLOG=0   -> nice -10 finishes first
//   make clean; make qemu CPUS=1 SCHEDULER=CFS            -> same, with vruntime log
//
// Each child does the same amount of work. Under CFS a lower nice value
// (higher weight) makes vruntime grow slower, so that child is picked more
// often and finishes earlier.

#include "kernel/types.h"
#include "user/user.h"

#define NCHILD 3

static int nices[NCHILD] = {10, 0, -10};

static void
spin(void)
{
  volatile unsigned long x = 0;
  for (unsigned long i = 0; i < 2000000000UL; i++)
    x += i;
}

int
main(void)
{
  for (int i = 0; i < NCHILD; i++) {
    int pid = fork();
    if (pid < 0) {
      fprintf(2, "cfstest: fork failed\n");
      exit(1);
    }
    if (pid == 0) {
      if (setnice(getpid(), nices[i]) < 0)
        fprintf(2, "cfstest: setnice failed\n");
      int start = uptime();
      spin();
      int end = uptime();
      printf("child %d (pid %d, nice %d) finished at tick %d (took %d ticks)\n",
             i, getpid(), nices[i], end, end - start);
      exit(0);
    }
  }
  for (int i = 0; i < NCHILD; i++)
    wait(0);
  printf("cfstest: all children done\n");
  exit(0);
}
