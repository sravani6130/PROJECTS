// mlfqtest: shows MLFQ queue movement.
//
//   make clean; make qemu CPUS=1 SCHEDULER=MLFQ MLFQLOG=1
//   $ mlfqtest
//
// Two CPU-bound children sink Q0 -> Q1 -> Q2 -> Q3 and then take turns in
// Q3 (round robin, 16-tick slices) until the 48-tick boost lifts them back to
// Q0. One I/O-bound child sleeps most of the time, never uses a full slice,
// stays in Q0 and preempts the CPU-bound ones whenever it wakes.

#include "kernel/types.h"
#include "user/user.h"

static void
spin(void)
{
  volatile unsigned long x = 0;
  for (unsigned long i = 0; i < 4000000000UL; i++)
    x += i;
}

int
main(void)
{
  int cpu1 = fork();
  if (cpu1 == 0) {
    spin();
    exit(0);
  }
  int cpu2 = fork();
  if (cpu2 == 0) {
    spin();
    exit(0);
  }
  int io = fork();
  if (io == 0) {
    for (int i = 0; i < 6; i++)
      sleep(20); // I/O-bound: blocks long before its 1-tick slice ends
    exit(0);
  }
  printf("mlfqtest: CPU-bound pids %d %d, I/O-bound pid %d\n", cpu1, cpu2, io);

  int wtime, rtime;
  for (int i = 0; i < 3; i++) {
    int pid = waitx(0, &wtime, &rtime);
    printf("mlfqtest: pid %d done, rtime %d, wtime %d\n", pid, rtime, wtime);
  }
  exit(0);
}
