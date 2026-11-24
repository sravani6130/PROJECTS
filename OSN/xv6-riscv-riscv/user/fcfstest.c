// fcfstest: shows the order in which CPU-bound children run.
//
// Run with one CPU to see the policy clearly:
//   make clean; make qemu CPUS=1 SCHEDULER=FCFS     -> children run one after another
//   make clean; make qemu CPUS=1                    -> round robin: children interleave

#include "kernel/types.h"
#include "user/user.h"

#define NCHILD 3

static void
spin(void)
{
  volatile unsigned long x = 0;
  for (unsigned long i = 0; i < 300000000UL; i++)
    x += i;
}

int
main(void)
{
  for (int i = 0; i < NCHILD; i++) {
    int pid = fork();
    if (pid < 0) {
      fprintf(2, "fcfstest: fork failed\n");
      exit(1);
    }
    if (pid == 0) {
      int start = uptime();
      printf("child %d (pid %d) started at tick %d\n", i, getpid(), start);
      spin();
      int end = uptime();
      printf("child %d (pid %d) finished at tick %d (ran %d ticks)\n", i,
             getpid(), end, end - start);
      exit(0);
    }
  }
  for (int i = 0; i < NCHILD; i++)
    wait(0);
  printf("fcfstest: all children done\n");
  exit(0);
}
