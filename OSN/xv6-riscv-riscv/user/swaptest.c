// ############## LLM Generated Code Begins ##############
// swaptest [npages] [nprocs]
// Each of nprocs processes sbrk()s npages pages, writes a pattern to every
// page, then reads all of them back and checks the pattern. When the
// pages do not fit in memory this exercises FIFO replacement, SWAPOUT
// and SWAPIN, with each process evicting only its own pages.
// Build with a small memory to see replacement quickly:
//   make clean; make qemu PHYSMEM=4 CPUS=1
//   $ swaptest 600 1      (fits in swap: all pages verify)
//   $ swaptest 600 2      (two processes, each with its own swap file)
//   $ swaptest 2000 1     (more than memory + 1024 swap slots: swap-exhausted)
#include "kernel/types.h"
#include "kernel/memstat.h"
#include "user/user.h"

#define PG 4096

static struct proc_mem_stat st;

static int
run(int npages)
{
  int pid = getpid();
  char *a = sbrk(npages * PG);
  if (a == SBRK_ERROR) {
    printf("swaptest: sbrk failed\n");
    return 1;
  }
  for (int i = 0; i < npages; i++)
    *(int *)(a + i * PG + 64) = i * 31 + pid;

  memstat(&st);
  printf("swaptest pid %d: wrote %d pages, resident=%d swapped=%d\n", pid,
         npages, st.num_resident_pages, st.num_swapped_pages);

  int bad = 0;
  for (int i = 0; i < npages; i++)
    if (*(int *)(a + i * PG + 64) != i * 31 + pid)
      bad++;
  memstat(&st);
  printf("swaptest pid %d: read back %d pages, %d wrong, resident=%d "
         "swapped=%d\n",
         pid, npages, bad, st.num_resident_pages, st.num_swapped_pages);
  return bad != 0;
}

int
main(int argc, char *argv[])
{
  int npages = argc > 1 ? atoi(argv[1]) : 600;
  int nprocs = argc > 2 ? atoi(argv[2]) : 1;

  if (nprocs <= 1) {
    int r = run(npages);
    printf("swaptest: %s\n", r ? "FAILED" : "OK");
    exit(r);
  }
  for (int i = 0; i < nprocs; i++) {
    if (fork() == 0)
      exit(run(npages));
  }
  int failed = 0;
  for (int i = 0; i < nprocs; i++) {
    int status;
    int pid = wait(&status);
    printf("swaptest: child %d exited with %d\n", pid, status);
    if (status != 0)
      failed++;
  }
  printf("swaptest: %s\n", failed ? "FAILED" : "OK");
  exit(failed != 0);
}
// ############## LLM Generated Code Ends ################
