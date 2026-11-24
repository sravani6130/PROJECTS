#include "types.h"
#include "riscv.h"
#include "defs.h"
#include "param.h"
#include "memlayout.h"
#include "spinlock.h"
#include "proc.h"
#include "vm.h"

uint64
sys_exit(void)
{
  int n;
  argint(0, &n);
  kexit(n);
  return 0; // not reached
}

uint64
sys_getpid(void)
{
  return myproc()->pid;
}

uint64
sys_fork(void)
{
  return kfork();
}

uint64
sys_wait(void)
{
  uint64 p;
  argaddr(0, &p);
// ############## LLM Generated Code Begins ##############
  // kwait() copies the status out while holding locks; fault it in now.
  if (p)
    vm_prefault(p, sizeof(int), 1);
  return kwait(p);
}

// memstat(struct proc_mem_stat *info): page-level snapshot of the caller.
uint64
sys_memstat(void)
{
  uint64 addr;

  argaddr(0, &addr);
  return vm_memstat(addr);
}
// ############## LLM Generated Code Ends ################

// waitx(status, wtime, rtime): like wait(), and also copies out the
// reaped child's waiting time and running time (in ticks).
uint64
sys_waitx(void)
{
  uint64 addr, waddr, raddr;
  uint wtime, rtime;
  struct proc *p = myproc();

  argaddr(0, &addr);
  argaddr(1, &waddr);
  argaddr(2, &raddr);
  if (addr)
    vm_prefault(addr, sizeof(int), 1);
  int pid = kwaitx(addr, &wtime, &rtime);
  if (pid < 0)
    return -1;
  if (copyout(p->pagetable, p->sz, waddr, (char *)&wtime, sizeof(wtime)) < 0 ||
      copyout(p->pagetable, p->sz, raddr, (char *)&rtime, sizeof(rtime)) < 0)
    return -1;
  return pid;
}

uint64
sys_sbrk(void)
{
  uint64 addr;
  int t;
  int n;

  argint(0, &n);
  argint(1, &t);
  addr = myproc()->sz;

// ############## LLM Generated Code Begins ##############
  // Demand paging: sbrk() never allocates physical pages, whatever t is.
  // growproc() only changes p->sz; pages are zero-filled on first use.
  (void)t;
  if (growproc(n) < 0)
    return -1;
  return addr;
// ############## LLM Generated Code Ends ################
}

uint64
sys_pause(void)
{
  int n;
  uint ticks0;

  argint(0, &n);
  if (n < 0)
    n = 0;
  acquire(&tickslock);
  ticks0 = ticks;
  while (ticks - ticks0 < n) {
    if (killed(myproc())) {
      release(&tickslock);
      return -1;
    }
    sleep_prepare(&ticks);
    release(&tickslock);
    sleep();
    acquire(&tickslock);
  }
  release(&tickslock);
  return 0;
}

// setnice(pid, nice): set a process's CFS priority (-20..19).
uint64
sys_setnice(void)
{
  int pid, nice;

  argint(0, &pid);
  argint(1, &nice);
  return setnice(pid, nice);
}

uint64
sys_kill(void)
{
  int pid;

  argint(0, &pid);
  return kkill(pid);
}

// return how many clock tick interrupts have occurred
// since start.
uint64
sys_uptime(void)
{
  uint xticks;

  acquire(&tickslock);
  xticks = ticks;
  release(&tickslock);
  return xticks;
}
