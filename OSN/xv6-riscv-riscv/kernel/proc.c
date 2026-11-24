#include "types.h"
#include "param.h"
#include "memlayout.h"
#include "riscv.h"
#include "spinlock.h"
#include "proc.h"
#include "defs.h"

struct cpu cpus[NCPU];

struct proc proc[NPROC];

struct proc *initproc;

int nextpid = 1;
struct spinlock pid_lock;

extern void forkret(void);
static void freeproc(struct proc *p);

extern char trampoline[]; // trampoline.S

// helps ensure that wakeups of wait()ing
// parents are not lost. helps obey the
// memory model when using p->parent.
// must be acquired before any p->lock.
struct spinlock wait_lock;

// Allocate a page for each process's kernel stack.
// Map it high in memory, followed by an invalid
// guard page.
void
proc_mapstacks(pagetable_t kpgtbl)
{
  struct proc *p;

  for (p = proc; p < &proc[NPROC]; p++) {
    char *pa = kalloc();
    if (pa == 0)
      panic("kalloc");
    uint64 va = KSTACK((int)(p - proc));
    kvmmap(kpgtbl, va, (uint64)pa, PGSIZE, PTE_R | PTE_W);
  }
}

// initialize the proc table.
void
procinit(void)
{
  struct proc *p;

  initlock(&pid_lock, "nextpid");
  initlock(&wait_lock, "wait_lock");
  for (p = proc; p < &proc[NPROC]; p++) {
    initlock(&p->lock, "proc");
    p->state = UNUSED;
    p->kstack = KSTACK((int)(p - proc));
  }
}

// Must be called with interrupts disabled,
// to prevent race with process being moved
// to a different CPU.
int
cpuid()
{
  int id = r_tp();
  return id;
}

// Return this CPU's cpu struct.
// Interrupts must be disabled.
struct cpu *
mycpu(void)
{
  int id = cpuid();
  struct cpu *c = &cpus[id];
  return c;
}

// Return the current struct proc *, or zero if none.
struct proc *
myproc(void)
{
  push_off();
  struct cpu *c = mycpu();
  struct proc *p = c->proc;
  pop_off();
  return p;
}

int
allocpid()
{
  int pid;

  acquire(&pid_lock);
  pid = nextpid;
  nextpid = nextpid + 1;
  release(&pid_lock);

  return pid;
}

#ifdef MLFQ
// Ticks a process may run in each queue before being demoted.
static const int mlfq_slice[MLFQ_NQUEUE] = {1, 4, 8, 16};
// Global "arrival" counter: a process joining a queue gets the next number,
// so within a queue the smallest qseq is the front (FIFO order).
static uint64 mlfq_seq = 0;
#endif

// Every transition to RUNNABLE goes through here (p->lock must be held).
// Under MLFQ this means "join the END of your current queue".
// fresh_slice = 1 for new processes and ones waking from sleep (they gave up
// the CPU voluntarily, so they get a full slice again). yield() passes 0: a
// process preempted by a higher queue keeps the ticks it already used, so it
// can't dodge demotion by being preempted repeatedly. (Demotion and the
// priority boost reset qticks themselves.)
static void
make_runnable(struct proc *p, int fresh_slice)
{
  p->state = RUNNABLE;
#ifdef MLFQ
  p->qseq = __sync_fetch_and_add(&mlfq_seq, 1);
  if (fresh_slice)
    p->qticks = 0;
#else
  (void)fresh_slice;
#endif
}

// Look in the process table for an UNUSED proc.
// If found, initialize state required to run in the kernel,
// and return with p->lock held.
// If there are no free procs, or a memory allocation fails, return 0.
static struct proc *
allocproc(void)
{
  struct proc *p;

  for (p = proc; p < &proc[NPROC]; p++) {
    acquire(&p->lock);
    if (p->state == UNUSED) {
      goto found;
    } else {
      release(&p->lock);
    }
  }
  return 0;

found:
  p->pid = allocpid();
  p->state = USED;
  p->ctime = ticks; // creation time, used by FCFS
  p->rtime = 0;
  p->etime = 0;

  // CFS defaults: normal priority, no CPU time used yet.
  p->nice = 0;
  p->weight = NICE_0_WEIGHT;
  p->vruntime = 0;
  p->time_slice = 0;
  p->slice_used = 0;

  // MLFQ: new processes start in the highest-priority queue.
  p->queue = 0;
  p->qticks = 0;
  p->qseq = 0;

// ############## LLM Generated Code Begins ##############
  // Demand paging: no executable or swap file until exec()/fork().
  p->exec_ip = 0;
  p->swap_ip = 0;
  p->nseg = 0;
  p->next_seq = 0;
  p->swap_used = 0;
  memset(p->swap_map, 0, sizeof(p->swap_map));
  p->text_start = p->text_end = p->data_start = p->data_end = 0;
  p->stack_bottom = p->stack_top = 0;
// ############## LLM Generated Code Ends ################

  // Allocate a trapframe page.
  if ((p->trapframe = (struct trapframe *)kalloc()) == 0) {
    freeproc(p);
    release(&p->lock);
    return 0;
  }

  // An empty user page table.
  p->pagetable = proc_pagetable(p);
  if (p->pagetable == 0) {
    freeproc(p);
    release(&p->lock);
    return 0;
  }

  // Set up new context to start executing at forkret,
  // which returns to user space.
  memset(&p->context, 0, sizeof(p->context));
  p->context.ra = (uint64)forkret;
  p->context.sp = p->kstack + PGSIZE;

  return p;
}

// free a proc structure and the data hanging from it,
// including user pages.
// p->lock must be held.
static void
freeproc(struct proc *p)
{
  if (p->trapframe)
    kfree((void *)p->trapframe);
  p->trapframe = 0;
  if (p->pagetable)
    proc_freepagetable(p->pagetable, p->sz);
  p->pagetable = 0;
  p->sz = 0;
  p->exec_ip = 0;
  p->swap_ip = 0;
  p->pid = 0;
  p->name[0] = 0;
  p->chan = 0;
  p->killed = 0;
  p->xstate = 0;
  p->state = UNUSED;
}

// Create a user page table for a given process, with no user memory,
// but with trampoline and trapframe pages.
pagetable_t
proc_pagetable(struct proc *p)
{
  pagetable_t pagetable;

  // An empty page table.
  pagetable = uvmcreate();
  if (pagetable == 0)
    return 0;

  // map the trampoline code (for system call return)
  // at the highest user virtual address.
  // only the supervisor uses it, on the way
  // to/from user space, so not PTE_U.
  if (mappages(pagetable, TRAMPOLINE, PGSIZE, (uint64)trampoline,
               PTE_R | PTE_X) < 0) {
    uvmfree(pagetable, 0);
    return 0;
  }

  // map the trapframe page just below the trampoline page, for
  // trampoline.S.
  if (mappages(pagetable, TRAPFRAME, PGSIZE, (uint64)(p->trapframe),
               PTE_R | PTE_W) < 0) {
    uvmunmap(pagetable, TRAMPOLINE, 1, 0);
    uvmfree(pagetable, 0);
    return 0;
  }

  return pagetable;
}

// Free a process's page table, and free the
// physical memory it refers to.
void
proc_freepagetable(pagetable_t pagetable, uint64 sz)
{
  uvmunmap(pagetable, TRAMPOLINE, 1, 0);
  uvmunmap(pagetable, TRAPFRAME, 1, 0);
  uvmfree(pagetable, sz);
}

// Set up first user process.
void
userinit(void)
{
  struct proc *p;

  p = allocproc();
  initproc = p;

  p->cwd = namei("/");

  make_runnable(p, 1);

  release(&p->lock);
}

// Grow or shrink user memory by n bytes.
// Return 0 on success, -1 on failure.
int
growproc(int n)
{
  uint64 sz;
  struct proc *p = myproc();

  sz = p->sz;
  if (n > 0) {
// ############## LLM Generated Code Begins ##############
    // Demand paging: only grow the size. Pages are zero-filled on the
    // first access (PAGEFAULT ... cause=heap).
    if (sz + n < sz || sz + n > TRAPFRAME) {
      return -1;
    }
    sz += n;
  } else if (n < 0) {
    if ((uint64)(-n) > sz)
      return -1;
    vm_shrink(p, sz, sz + n); // free swap slots of the removed pages
    sz = uvmdealloc(p->pagetable, sz, sz + n);
// ############## LLM Generated Code Ends ################
  }
  p->sz = sz;
  return 0;
}

// Create a new process, copying the parent.
// Sets up child kernel stack to return as if from fork() system call.
int
kfork(void)
{
  int i, pid;
  struct proc *np;
  struct proc *p = myproc();

  // Allocate process.
  if ((np = allocproc()) == 0) {
    return -1;
  }

// ############## LLM Generated Code Begins ##############
  // Copy user memory from parent to child. This can sleep (swap file
  // I/O), so np->lock is dropped; np is USED, so no one else runs it.
  np->sz = p->sz;
  release(&np->lock);
  if (vm_fork(p, np) < 0) {
    vm_free(np, 0);
    acquire(&np->lock);
// ############## LLM Generated Code Ends ################
    freeproc(np);
    release(&np->lock);
    return -1;
  }
  acquire(&np->lock);

  // copy saved user registers.
  *(np->trapframe) = *(p->trapframe);

  // Cause fork to return 0 in the child.
  np->trapframe->a0 = 0;

  // increment reference counts on open file descriptors.
  for (i = 0; i < NOFILE; i++)
    if (p->ofile[i])
      np->ofile[i] = filedup(p->ofile[i]);
  np->cwd = idup(p->cwd);

  safestrcpy(np->name, p->name, sizeof(p->name));

  // Child inherits the parent's priority (vruntime still starts at 0).
  np->nice = p->nice;
  np->weight = p->weight;

  pid = np->pid;

  release(&np->lock);

  acquire(&wait_lock);
  np->parent = p;
  release(&wait_lock);

  acquire(&np->lock);
  make_runnable(np, 1);
  release(&np->lock);

  return pid;
}

// Pass p's abandoned children to init.
// Caller must hold wait_lock.
void
reparent(struct proc *p)
{
  struct proc *pp;

  for (pp = proc; pp < &proc[NPROC]; pp++) {
    if (pp->parent == p) {
      pp->parent = initproc;
      wakeup(initproc);
    }
  }
}

// Exit the current process.  Does not return.
// An exited process remains in the zombie state
// until its parent calls wait().
void
kexit(int status)
{
  struct proc *p = myproc();

  if (p == initproc)
    panic("init exiting");

  // Close all open files.
  for (int fd = 0; fd < NOFILE; fd++) {
    if (p->ofile[fd]) {
      struct file *f = p->ofile[fd];
      fileclose(f);
      p->ofile[fd] = 0;
    }
  }

// ############## LLM Generated Code Begins ##############
  // Delete the swap file (SWAPCLEANUP) and release the executable.
  // The resident frames are freed with the page table in freeproc().
  vm_free(p, 1);
// ############## LLM Generated Code Ends ################

  begin_op();
  iput(p->cwd);
  end_op();
  p->cwd = 0;

  acquire(&wait_lock);

  // Give any children to init.
  reparent(p);

  // Parent might be sleeping in wait().
  wakeup(p->parent);

  acquire(&p->lock);

  p->xstate = status;
  p->etime = ticks; // exit time, used by waitx
  p->state = ZOMBIE;

  release(&wait_lock);

  // Jump into the scheduler, never to return.
  sched();
  panic("zombie exit");
}

// Wait for a child process to exit and return its pid.
// Return -1 if this process has no children.
int
kwait(uint64 addr)
{
  return kwaitx(addr, 0, 0);
}

// Like kwait(), but also reports the reaped child's times:
//   *rtime = ticks it spent RUNNING
//   *wtime = ticks it existed but was not running = etime - ctime - rtime
// wtime/rtime may be 0 if the caller doesn't need them.
int
kwaitx(uint64 addr, uint *wtime, uint *rtime)
{
  struct proc *pp;
  int havekids, pid;
  struct proc *p = myproc();

  acquire(&wait_lock);

  for (;;) {
    // Scan through table looking for exited children.
    havekids = 0;
    for (pp = proc; pp < &proc[NPROC]; pp++) {
      if (pp->parent == p) {
        // make sure the child isn't still in exit() or swtch().
        acquire(&pp->lock);

        havekids = 1;
        if (pp->state == ZOMBIE) {
          // Found one.
          pid = pp->pid;
          if (rtime)
            *rtime = pp->rtime;
          if (wtime)
            *wtime = pp->etime - pp->ctime - pp->rtime;
          if (addr != 0 &&
              copyout(p->pagetable, p->sz, addr, (char *)&pp->xstate,
                      sizeof(pp->xstate)) < 0) {
            release(&pp->lock);
            release(&wait_lock);
            return -1;
          }
          pp->parent = 0;
          freeproc(pp);
          release(&pp->lock);
          release(&wait_lock);
          return pid;
        }
        release(&pp->lock);
      }
    }

    // No point waiting if we don't have any children.
    if (!havekids || killed(p)) {
      release(&wait_lock);
      return -1;
    }

    // Wait for a child to exit.
    sleep_prepare(p); //DOC: wait-sleep
    release(&wait_lock);
    sleep();
    acquire(&wait_lock);
  }
}

// nice -> weight table: weight = 1024 / 1.25^nice (rounded).
// Index 0 is nice -20, index 39 is nice 19. Same values as Linux.
static const uint64 prio_to_weight[40] = {
  // clang-format off
  /* -20 */ 88761, 71755, 56483, 46273, 36291,
  /* -15 */ 29154, 23254, 18705, 14949, 11916,
  /* -10 */  9548,  7620,  6100,  4904,  3906,
  /*  -5 */  3121,  2501,  1991,  1586,  1277,
  /*   0 */  1024,   820,   655,   526,   423,
  /*   5 */   335,   272,   215,   172,   137,
  /*  10 */   110,    87,    70,    56,    45,
  /*  15 */    36,    29,    23,    18,    15,
  // clang-format on
};

// Set the nice value (and therefore weight) of process pid.
// Returns 0 on success, -1 if nice is out of range or pid not found.
int
setnice(int pid, int nice)
{
  struct proc *p;

  if (nice < -20 || nice > 19)
    return -1;
  for (p = proc; p < &proc[NPROC]; p++) {
    acquire(&p->lock);
    if (p->pid == pid && p->state != UNUSED) {
      p->nice = nice;
      p->weight = prio_to_weight[nice + 20];
      release(&p->lock);
      return 0;
    }
    release(&p->lock);
  }
  return -1;
}

// Called on every timer interrupt on this CPU (from usertrap/kerneltrap).
// Does per-tick accounting for the running process and returns 1 if it
// should give up the CPU now (yield), 0 if it should keep running.
int
sched_tick(void)
{
  struct proc *p = myproc();
  if (p == 0)
    return 0;

  int preempt;
  acquire(&p->lock);
  if (p->state == RUNNING)
    p->rtime++; // running-time accounting (all policies), reported by waitx

#if defined(FCFS)
  preempt = 0; // non-preemptive: never forced off the CPU
#elif defined(CFS)
  preempt = 0;
  if (p->state == RUNNING) {
    // vruntime grows slower for heavy (high-priority) processes:
    //   nice 0 -> +1000/tick, nice -20 -> +11/tick, nice 19 -> +68266/tick
    p->vruntime += (VRUNTIME_SCALE * NICE_0_WEIGHT) / p->weight;
    p->slice_used++;
    if (p->slice_used >= p->time_slice)
      preempt = 1; // slice used up -> preempt
  }
#elif defined(MLFQ)
  preempt = 0;
  if (p->state == RUNNING) {
    p->qticks++;
    if (p->qticks >= mlfq_slice[p->queue]) {
      // Used its whole slice: demote one level (queue 3 stays in 3, which
      // with re-joining the end of the queue gives round robin there).
#ifdef MLFQ_LOG
      if (p->queue < MLFQ_NQUEUE - 1)
        printk("[MLFQ] tick %d: PID %d used full slice, Q%d -> Q%d\n", ticks,
               p->pid, p->queue, p->queue + 1);
#endif
      if (p->queue < MLFQ_NQUEUE - 1)
        p->queue++;
      p->qticks = 0; // fresh slice in the new (or same, for Q3) queue
      preempt = 1;
    }
  }
  int myqueue = p->queue;
  release(&p->lock);

  // A process waiting in a higher queue preempts us at this tick boundary.
  // It keeps its queue and the ticks already used, and re-joins the end
  // of the queue (yield -> make_runnable(p, 0)).
  if (!preempt && mlfq_higher_waiting(p, myqueue)) {
#ifdef MLFQ_LOG
    printk("[MLFQ] tick %d: PID %d (Q%d) preempted by a higher-queue process\n",
           ticks, p->pid, myqueue);
#endif
    preempt = 1;
  }
  return preempt;
#else
  preempt = 1; // round robin: switch on every tick
#endif
  release(&p->lock);
  return preempt;
}

#ifdef MLFQ
// Is any process other than self RUNNABLE in a queue above `queue`?
// Caller must not hold any proc lock.
int
mlfq_higher_waiting(struct proc *self, int queue)
{
  struct proc *p;
  int found = 0;

  if (queue == 0)
    return 0;
  for (p = proc; p < &proc[NPROC] && !found; p++) {
    if (p == self)
      continue;
    acquire(&p->lock);
    if (p->state == RUNNABLE && p->queue < queue)
      found = 1;
    release(&p->lock);
  }
  return found;
}

// Priority boost (starvation prevention): called from clockintr() on CPU 0
// every BOOST_INTERVAL ticks. Moves every process back to queue 0 with a
// fresh slice; their relative order (qseq) is kept.
void
mlfq_boost(void)
{
  struct proc *p;

#ifdef MLFQ_LOG
  printk("[MLFQ] tick %d: priority boost, all processes -> Q0\n", ticks);
#endif
  for (p = proc; p < &proc[NPROC]; p++) {
    acquire(&p->lock);
    if (p->state != UNUSED) {
      p->queue = 0;
      p->qticks = 0;
    }
    release(&p->lock);
  }
}
#endif

// Per-CPU process scheduler.
// Each CPU calls scheduler() after setting itself up.
// Scheduler never returns.  It loops, doing:
//  - choose a process to run.
//  - swtch to start running that process.
//  - eventually that process transfers control
//    via swtch back to the scheduler.
void
scheduler(void)
{
  struct proc *p;
  struct cpu *c = mycpu();

  c->proc = 0;
  for (;;) {
    // The most recent process to run may have had interrupts
    // turned off; enable them to avoid a deadlock if all
    // processes are waiting. Then turn them back off
    // to avoid a possible race between an interrupt
    // and wfi.
    intr_on();
    intr_off();

#ifdef FCFS
    // ---------- FCFS: First Come First Serve (non-preemptive) ----------
    // Scan the whole table and pick the RUNNABLE process with the
    // smallest creation time (ties broken by lower pid).
    // We keep the lock of the best candidate held while scanning the
    // rest, so it can't change state under us. Locks are always taken in
    // increasing table order, so two CPUs scanning at once can't deadlock.
    struct proc *chosen = 0;
    for (p = proc; p < &proc[NPROC]; p++) {
      acquire(&p->lock);
      if (p->state == RUNNABLE &&
          (chosen == 0 || p->ctime < chosen->ctime ||
           (p->ctime == chosen->ctime && p->pid < chosen->pid))) {
        if (chosen)
          release(&chosen->lock); // previous best is no longer best
        chosen = p;               // keep chosen->lock held
      } else {
        release(&p->lock);
      }
    }

    if (chosen == 0) {
      // nothing to run; stop running on this core until an interrupt.
      asm volatile("wfi");
      continue;
    }

    // Run it. Timer interrupts don't call yield() under FCFS (see trap.c),
    // so it keeps the CPU until it exits or blocks (sleep/wait/IO).
    p = chosen;
    p->state = RUNNING;
    c->proc = p;
    swtch(&c->context, &p->context);

    // Don't re-enable interrupts on release.
    mycpu()->intena = 0;
    c->proc = 0;
    release(&p->lock);
#elif defined(CFS)
    // ---------- CFS: Completely Fair Scheduler ----------
    // Pick the RUNNABLE process with the smallest vruntime (ties: lower pid).
    // Same locking pattern as FCFS: hold only the best candidate's lock.
    struct proc *chosen = 0;
    int nrunnable = 0;
#ifdef CFS_LOG
    int log_pid[NPROC];
    uint64 log_vr[NPROC];
#endif
    for (p = proc; p < &proc[NPROC]; p++) {
      acquire(&p->lock);
      if (p->state == RUNNABLE) {
#ifdef CFS_LOG
        log_pid[nrunnable] = p->pid;
        log_vr[nrunnable] = p->vruntime;
#endif
        nrunnable++;
        if (chosen == 0 || p->vruntime < chosen->vruntime ||
            (p->vruntime == chosen->vruntime && p->pid < chosen->pid)) {
          if (chosen)
            release(&chosen->lock); // previous best is no longer best
          chosen = p;               // keep chosen->lock held
          continue;
        }
      }
      release(&p->lock);
    }

    if (chosen == 0) {
      // nothing to run; stop running on this core until an interrupt.
      asm volatile("wfi");
      continue;
    }

#ifdef CFS_LOG
    // Log every runnable process's vruntime before this decision.
    printk("[Scheduler Tick]\n");
    for (int i = 0; i < nrunnable; i++)
      printk("PID: %d | vRuntime: %ld\n", log_pid[i], log_vr[i]);
    printk("--> Scheduling PID %d (lowest vRuntime)\n", chosen->pid);
#endif

    // Time slice: share the target latency among runnable processes,
    // but never less than the minimum granularity.
    int slice = TARGET_LATENCY / nrunnable;
    if (slice < MIN_GRANULARITY)
      slice = MIN_GRANULARITY;

    p = chosen;
    p->time_slice = slice;
    p->slice_used = 0;
    p->state = RUNNING;
    c->proc = p;
    swtch(&c->context, &p->context);

    // Don't re-enable interrupts on release.
    mycpu()->intena = 0;
    c->proc = 0;
    release(&p->lock);
#elif defined(MLFQ)
    // ---------- MLFQ: Multi-Level Feedback Queue (preemptive) ----------
    // Pick from the highest non-empty queue (lowest queue number); within a
    // queue, the process that joined it first (lowest qseq) -> FIFO / RR.
    // Same locking pattern as FCFS/CFS: hold only the best candidate's lock.
    struct proc *chosen = 0;
    for (p = proc; p < &proc[NPROC]; p++) {
      acquire(&p->lock);
      if (p->state == RUNNABLE &&
          (chosen == 0 || p->queue < chosen->queue ||
           (p->queue == chosen->queue && p->qseq < chosen->qseq))) {
        if (chosen)
          release(&chosen->lock);
        chosen = p;
        continue;
      }
      release(&p->lock);
    }

    if (chosen == 0) {
      // nothing to run; stop running on this core until an interrupt.
      asm volatile("wfi");
      continue;
    }

    // Demotion, preemption by higher queues and the priority boost all happen
    // at tick boundaries in sched_tick()/clockintr().
    p = chosen;
    p->state = RUNNING;
    c->proc = p;
    swtch(&c->context, &p->context);

    // Don't re-enable interrupts on release.
    mycpu()->intena = 0;
    c->proc = 0;
    release(&p->lock);
#else
    // ---------- Default: Round Robin (original xv6 scheduler) ----------
    int found = 0;
    for (p = proc; p < &proc[NPROC]; p++) {
      acquire(&p->lock);
      if (p->state == RUNNABLE) {
        // Switch to chosen process.  It is the process's job
        // to release its lock and then reacquire it
        // before jumping back to us.
        p->state = RUNNING;
        c->proc = p;
        swtch(&c->context, &p->context);

        // Don't re-enable interrupts on release.
        mycpu()->intena = 0;

        // Process is done running for now.
        // It should have changed its p->state before coming back.
        c->proc = 0;
        found = 1;
      }
      release(&p->lock);
    }
    if (found == 0) {
      // nothing to run; stop running on this core until an interrupt.
      asm volatile("wfi");
    }
#endif
  }
}

// Switch to scheduler.  Must hold only p->lock
// and have changed proc->state. Saves and restores
// intena because intena is a property of this
// kernel thread, not this CPU. It should
// be proc->intena and proc->noff, but that would
// break in the few places where a lock is held but
// there's no process.
void
sched(void)
{
  int intena;
  struct proc *p = myproc();

  if (!holding(&p->lock))
    panic("sched p->lock");
  if (mycpu()->noff != 1)
    panic("sched locks");
  if (p->state == RUNNING)
    panic("sched RUNNING");
  if (intr_get())
    panic("sched interruptible");

  intena = mycpu()->intena;
  swtch(&p->context, &mycpu()->context);
  mycpu()->intena = intena;
}

// Give up the CPU for one scheduling round.
void
yield(void)
{
  struct proc *p = myproc();
  acquire(&p->lock);
  make_runnable(p, 0); // preempted: keep slice progress
  sched();
  release(&p->lock);
}

// A fork child's very first scheduling by scheduler()
// will swtch to forkret.
void
forkret(void)
{
  extern char userret[];
  static int first = 1;
  struct proc *p = myproc();

  // Still holding p->lock from scheduler.
  release(&p->lock);

  if (first) {
    first = 0;

    // File system initialization must be run in the context of a
    // regular process (e.g., because it calls sleep), and thus cannot
    // be run from main().
    fsinit(ROOTDEV);

    // We can invoke kexec() now that file system is initialized.
    // Put the return value (argc) of kexec into a0.
    p->trapframe->a0 = kexec("/init", (char *[]){"/init", 0});
    if (p->trapframe->a0 == -1) {
      panic("exec");
    }
  }

  // return to user space, mimicing usertrap()'s return.
  prepare_return();
  uint64 satp = MAKE_SATP(p->pagetable);
  uint64 trampoline_userret = TRAMPOLINE + (userret - trampoline);
  ((void (*)(uint64))trampoline_userret)(satp);
}

// Register current process as waiting for wakeups on chan.
void
sleep_prepare(void *chan)
{
  struct proc *p = myproc();

  acquire(&p->lock);
  if (chan == 0)
    panic("sleep_prepare: zero chan");
  p->chan = chan;
  release(&p->lock);
}

// Put the thread to sleep.  Assumes sleep_prepare() was called before.
// If the channel registered by sleep_prepare() has been woken up in
// the meantime, do not go to sleep, and instead return immediately.
void
sleep(void)
{
  struct proc *p = myproc();

  acquire(&p->lock);
  if (p->chan != 0) {
    p->state = SLEEPING;
    sched();
  }
  release(&p->lock);
}

// Wake up all processes sleeping on channel chan.
void
wakeup(void *chan)
{
  struct proc *p;

  for (p = proc; p < &proc[NPROC]; p++) {
    acquire(&p->lock);
    if (p->chan == chan) {
      // If the process is waiting for wakeups on this channel,
      // signal that the wakeup happened by clearing p->chan.
      p->chan = 0;

      // If this waiting process has gotten so far as to actually
      // go to sleep, also set it back to RUNNING.
      if (p->state == SLEEPING) {
        make_runnable(p, 1); // woke from sleep: fresh slice
      }
    }
    release(&p->lock);
  }
}

// Kill the process with the given pid.
// The victim won't exit until it tries to return
// to user space (see usertrap() in trap.c).
int
kkill(int pid)
{
  struct proc *p;

  if (pid == 0)
    return -1;

  for (p = proc; p < &proc[NPROC]; p++) {
    acquire(&p->lock);
    if (p->pid == pid) {
      p->killed = 1;
      if (p->state == SLEEPING) {
        // Wake process from sleep().
        make_runnable(p, 1);
      }
      release(&p->lock);
      return 0;
    }
    release(&p->lock);
  }
  return -1;
}

void
setkilled(struct proc *p)
{
  acquire(&p->lock);
  p->killed = 1;
  release(&p->lock);
}

int
killed(struct proc *p)
{
  int k;

  acquire(&p->lock);
  k = p->killed;
  release(&p->lock);
  return k;
}

// Copy to either a user address, or kernel address,
// depending on usr_dst.
// Returns 0 on success, -1 on error.
int
either_copyout(int user_dst, uint64 dst, void *src, uint64 len)
{
  struct proc *p = myproc();
  if (user_dst) {
    return copyout(p->pagetable, p->sz, dst, src, len);
  } else {
    memmove((char *)dst, src, len);
    return 0;
  }
}

// Copy from either a user address, or kernel address,
// depending on usr_src.
// Returns 0 on success, -1 on error.
int
either_copyin(void *dst, int user_src, uint64 src, uint64 len)
{
  struct proc *p = myproc();
  if (user_src) {
    return copyin(p->pagetable, p->sz, dst, src, len);
  } else {
    memmove(dst, (char *)src, len);
    return 0;
  }
}

// Print a process listing to console.  For debugging.
// Runs when user types ^P on console.
// No lock to avoid wedging a stuck machine further.
void
procdump(void)
{
  static char *states[] = {
    // clang-format off
    [UNUSED]    = "unused",
    [USED]      = "used",
    [SLEEPING]  = "sleep ",
    [RUNNABLE]  = "runble",
    [RUNNING]   = "run   ",
    [ZOMBIE]    = "zombie"
    // clang-format on
  };
  struct proc *p;
  char *state;

  printk("\n");
  for (p = proc; p < &proc[NPROC]; p++) {
    if (p->state == UNUSED)
      continue;
    if (p->state >= 0 && p->state < NELEM(states) && states[p->state])
      state = states[p->state];
    else
      state = "???";
    printk("%d %s %s ctime=%d rtime=%d nice=%d vruntime=%ld slice=%d/%d q=%d",
           p->pid, state, p->name, p->ctime, p->rtime, p->nice, p->vruntime,
           p->slice_used, p->time_slice, p->queue);
    printk("\n");
  }
}
