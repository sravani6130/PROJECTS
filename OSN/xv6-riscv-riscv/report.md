# xv6 Report — getreadcount, FCFS, CFS, MLFQ (bonus)

## Building

```
make clean; make qemu                          # Round Robin (default)
make clean; make qemu SCHEDULER=FCFS
make clean; make qemu SCHEDULER=CFS            # with [Scheduler Tick] log
make clean; make qemu SCHEDULER=CFS CFSLOG=0   # CFS without the log
make clean; make qemu SCHEDULER=MLFQ           # MLFQLOG=1 for the queue-event log
```

The Makefile passes `-D$(SCHEDULER)` to the compiler (RR when not given), so exactly one
policy is compiled in. `make clean` is needed when switching so every file is rebuilt.

---

## Part A — `getreadcount`

- **Counter:** `static uint readcount` in `kernel/sysfile.c`. In `sys_read()`, after
  `fileread()` returns `r`, if `r > 0` it is added with `__sync_fetch_and_add`, so concurrent
  reads on several CPUs are not lost. Only bytes actually read are counted (errors/EOF add 0).
  Being a 32-bit unsigned int, it wraps to 0 on overflow.
- **Syscall:** `sys_getreadcount()` returns the counter. Registered as `SYS_getreadcount` (23)
  in `syscall.h`/`syscall.c`, with the user stub from `usys.pl` and the prototype in `user.h`.
- **`user/readcount.c`:** prints the count, reads 100 bytes from a file (default `README`),
  prints the count again and checks the increase equals the bytes read (unsigned subtraction,
  so it is correct even across a wrap).

```
$ readcount
Initial read count: 10
Read 100 bytes from README
Read count after read: 110
Increase: 100 bytes
OK: read count increased by 100 as expected
```

---

## Part B — Common changes

- **New `struct proc` fields** (`kernel/proc.h`): `ctime`, `rtime`, `etime`, `nice`, `weight`,
  `vruntime`, `time_slice`, `slice_used`. All are initialised in `allocproc()`.
- **One timer hook for all policies:** both timer-interrupt paths in `kernel/trap.c`
  (`usertrap`, `kerneltrap`) now do `if (which_dev == 2 && sched_tick()) yield();`.
  `sched_tick()` (`kernel/proc.c`) does the per-tick accounting for the running process and
  returns whether it must be preempted: RR → always, FCFS → never, CFS → when its slice is used up.
- **`scheduler()`** is split with `#if defined(FCFS) / #elif defined(CFS) / #else`, where the
  `#else` branch is the original round-robin code, kept unchanged.
- **`procdump()`** (Ctrl-P) also prints ctime, nice, vruntime and slice used/total.

## FCFS

- **Creation time:** `allocproc()` sets `p->ctime = ticks`. Every process is created through
  `allocproc()`, so all processes get an arrival time.
- **Selection:** the scheduler scans the whole process table and picks the RUNNABLE process
  with the smallest `ctime` (ties → smaller pid, since several forks can happen in one tick).
  The best candidate's lock is kept while scanning; locks are taken in table order, so two CPUs
  scanning together cannot deadlock.
- **Non-preemptive:** `sched_tick()` returns 0 under FCFS, so a timer interrupt never forces a
  `yield()`. A process leaves the CPU only when it exits or blocks (sleep, wait, I/O).

`fcfstest` (3 CPU-bound children, 1 CPU) shows they run strictly one after another:

```
child 0 (pid 5) started at tick 48      child 0 finished at tick 53
child 1 (pid 6) started at tick 54      child 1 finished at tick 59
child 2 (pid 7) started at tick 59      child 2 finished at tick 65
```
(Under RR the same three start at ticks 4, 5, 6 and all finish at ticks 19–20.)

## CFS

### B.1 Priority
- Each process has `nice` (−20..19, default 0, inherited from the parent on `fork`).
- `weight = 1024 / 1.25^nice` is taken from a 40-entry table `prio_to_weight[]` (same values
  as Linux: nice −20 = 88761, 0 = 1024, 19 = 15), because the kernel has no floating point.
- A new syscall `setnice(pid, nice)` (number 24) changes a process's nice/weight; it is needed
  to test priorities.

### B.2 Virtual runtime
- `vruntime` starts at 0 in `allocproc()`.
- On every timer tick, `sched_tick()` adds `1000 × 1024 / weight` to the running process's
  vruntime, i.e. vruntime is measured in 1/1000 of a nice-0 tick. The ×1000 scaling keeps
  high-weight increments non-zero in integer arithmetic (nice 0: +1000/tick, nice −10: +107,
  nice 10: +9309, nice −20: +11).

### B.2 Scheduling
- At every decision the scheduler scans the table and runs the RUNNABLE process with the
  **lowest vruntime** (ties → lower pid). This always selects the same process as the head of a
  vruntime-sorted queue would; with at most NPROC = 64 processes a scan is cheap and needs no
  extra bookkeeping when processes become runnable. Same locking scheme as FCFS.
- A process that sleeps keeps its vruntime when it wakes. Wake-ups do not preempt the running
  process; it finishes its slice first.

### B.3 Time slices
- When a process is chosen: `time_slice = 48 / N` where N = number of RUNNABLE processes at
  that decision, with a minimum of 3 ticks; `slice_used` is reset to 0.
- `sched_tick()` increments `slice_used` each tick and requests a `yield()` once
  `slice_used ≥ time_slice`.

### Logging
Compiled in with `SCHEDULER=CFS` (default `CFSLOG=1`). During the scan the scheduler records
every runnable PID and its vruntime; after the scan it prints them and the chosen PID.

**Excerpt 1 — `cfstest`** (3 equal CPU-bound children with nice 10 / 0 / −10; pids 4 / 5 / 6).
N = 3, so each slice is 48/3 = 16 ticks:

```
[Scheduler Tick]
PID: 4 | vRuntime: 0
PID: 5 | vRuntime: 0
PID: 6 | vRuntime: 0
--> Scheduling PID 4 (lowest vRuntime)
[Scheduler Tick]
PID: 4 | vRuntime: 148944        <- nice 10: 16 ticks × 9309
PID: 5 | vRuntime: 0
PID: 6 | vRuntime: 0
--> Scheduling PID 5 (lowest vRuntime)
[Scheduler Tick]
PID: 4 | vRuntime: 148944
PID: 5 | vRuntime: 16000         <- nice 0: 16 ticks × 1000
PID: 6 | vRuntime: 0
--> Scheduling PID 6 (lowest vRuntime)
[Scheduler Tick]
PID: 4 | vRuntime: 148944
PID: 5 | vRuntime: 16000
PID: 6 | vRuntime: 1712          <- nice -10: 16 ticks × 107
--> Scheduling PID 6 (lowest vRuntime)
[Scheduler Tick]
PID: 4 | vRuntime: 148944
PID: 5 | vRuntime: 16000
PID: 6 | vRuntime: 3424
--> Scheduling PID 6 (lowest vRuntime)
```

Every decision picks the lowest vruntime, and the chosen process's vruntime grows after each
slice in inverse proportion to its weight. Result (1 CPU):

| child | nice | finished at (CFS) | finished at (RR) |
|---|---|---|---|
| child 2 | −10 | tick 70 | tick 116 |
| child 1 | 0 | tick 93 | tick 116 |
| child 0 | 10 | tick 116 | tick 117 |

**Excerpt 2 — `schedulertest`** (pids 4–8 I/O-bound, 9–13 CPU-bound, all nice 0). The five
CPU-bound processes have each run one 9-tick slice (48/5 runnable = 9) and have vruntime 9000.
The I/O-bound ones (vruntime 0) are picked first whenever they are runnable: xv6's `pause()`
wakes sleepers on every tick to re-check the time, and they immediately sleep again, using
almost no CPU.

```
[Scheduler Tick]
PID: 4 | vRuntime: 0
PID: 5 | vRuntime: 0
PID: 6 | vRuntime: 0
PID: 7 | vRuntime: 0
PID: 8 | vRuntime: 0
PID: 9 | vRuntime: 9000
PID: 10 | vRuntime: 9000
PID: 11 | vRuntime: 9000
PID: 12 | vRuntime: 9000
PID: 13 | vRuntime: 9000
--> Scheduling PID 4 (lowest vRuntime)
[Scheduler Tick]
PID: 5 | vRuntime: 0
...
PID: 13 | vRuntime: 9000
--> Scheduling PID 5 (lowest vRuntime)
```

---

## Performance comparison

### Method
- **Time accounting:** `rtime` is incremented in `sched_tick()` on each tick the process is
  RUNNING (all policies); `etime = ticks` is set in `kexit()`.
- **`waitx(status, &wtime, &rtime)`** (syscall 25) behaves like `wait()` and also returns the
  reaped child's `rtime` and `wtime = etime − ctime − rtime` (all non-running time, including
  sleeping). `kwait()` now calls the shared `kwaitx()`.
- **`schedulertest`:** forks 10 children — 5 I/O-bound (`sleep(200)`) and 5 CPU-bound
  (1,000,000,000-iteration busy loop) — reaps them with `waitx` and prints the averages.
  (The course link to the original file needs an IIIT login; this is the standard version of
  the test. A `sleep()` wrapper for `pause()` was added to `user/ulib.c`, as this xv6 renamed it.)
- **Setup:** `CPUS=1`, `CFSLOG=0` (printing would distort timing), 3 runs per scheduler in
  one boot. Times are in ticks.

### Results

| Scheduler | Run 1 (rtime / wtime) | Run 2 | Run 3 | **Avg rtime** | **Avg wtime** |
|---|---|---|---|---|---|
| Round Robin | 9 / 138 | 9 / 137 | 9 / 138 | **9** | **137.7** |
| FCFS | 10 / 119 | 10 / 119 | 9 / 119 | **9.7** | **119** |
| CFS | 9 / 137 | 10 / 138 | 10 / 138 | **9.7** | **137.7** |
| MLFQ (bonus) | 9 / 136 | 9 / 137 | 9 / 137 | **9** | **136.7** |

### Analysis
- **Running time is the same (~9–10 ticks)** for all policies: it is the CPU work each process
  needs (CPU-bound ≈ 19 ticks, I/O-bound ≈ 0, averaged over 10), which the scheduler does not
  change. The small differences come from tick-granularity rounding.
- **Wait time.** The I/O-bound processes wait ≈ 200 ticks in every policy, since they sleep
  200 ticks and sleeping counts as waiting. The difference comes from the 5 CPU-bound processes
  (~95 ticks of total work):
  - **FCFS (119)** runs them one after another. They finish at ≈ 19, 38, 57, 76, 95, so their
    waits are ≈ 0, 19, 38, 57, 76 (mean ≈ 38) → (5·200 + 5·38)/10 ≈ 119.
  - **RR (137.7)** interleaves them every tick, so all five finish near the end (≈ 95) and each
    waits ≈ 76 → (5·200 + 5·76)/10 ≈ 138.
  - **CFS (137.7)**: all processes have nice 0, so CFS divides the CPU equally just like RR, only
    in longer slices (≈ 9 ticks). All CPU-bound processes again finish near the end, giving the
    same average wait as RR.
  - **MLFQ (136.7)**: the I/O-bound processes never use a full slice and stay in queue 0, so they
    are served immediately whenever they wake. The CPU-bound ones sink to the lower queues and
    share the CPU there. The 48-tick boost keeps lifting them back to queue 0, so over the run
    they still share the CPU in turns and finish close together. This gives about the same
    average wait as RR/CFS (slightly lower).
- **Trade-off.** FCFS has the lowest average wait on this workload because it never shares the
  CPU: for equal-length jobs, running them to completion one at a time minimises the average
  completion time, while sharing makes every job finish late. However, it gives
  no responsiveness: a long job blocks every later one (convoy effect), and an infinite loop
  would block the CPU. RR and CFS are fair and responsive. CFS additionally respects priorities
  (see the `cfstest` table: nice −10 finished at tick 70 vs. 116 under RR) and switches less
  often than RR (slices of 48/N ticks instead of 1 tick). MLFQ needs no priorities from the
  user: it learns from behaviour which processes are interactive (keep them in queue 0, so they
  respond fast) and which are CPU-bound (move them down to longer slices with fewer switches).
  The boost prevents starvation.

## Bonus — Preemptive MLFQ (`SCHEDULER=MLFQ`)

### Implementation
- **Queues without linked lists.** Each process stores `queue` (0–3), `qticks` (ticks used of the
  current slice) and `qseq` (taken from a global counter when it joins a queue). "Front of
  queue q" means the RUNNABLE process in q with the smallest `qseq`, so FIFO order within a queue
  follows from that number.
- **Joining a queue.** Every transition to RUNNABLE (`userinit`, `fork`, `yield`, `wakeup`,
  `kill`) goes through one helper, `make_runnable(p, fresh_slice)`. It gives the process a new
  `qseq`, putting it at the end of its queue.
- **New processes.** `allocproc()` sets `queue = 0`, so a new process joins the end of queue 0.
- **Selection.** The scheduler picks the RUNNABLE process with the lowest `queue`, then the lowest
  `qseq` (same locking scheme as FCFS/CFS).
- **Full slice → demote** (`sched_tick()`). Each tick, `qticks++`. When `qticks` reaches the
  slice of the current queue (1, 4, 8, 16), the process moves one queue down (it stays in queue
  3), gets `qticks = 0` and yields. It therefore joins the end of the lower queue.
- **Queue 3 is round robin.** A process that uses its 16 ticks stays in queue 3 and joins its end,
  so queue-3 processes take turns.
- **Leaving early (I/O) → same queue.** A process that sleeps before its slice ends keeps its
  queue. When `wakeup()` makes it RUNNABLE, it joins the end of the same queue with a fresh slice.
- **Preemption by a higher queue.** At every tick, `sched_tick()` checks
  (`mlfq_higher_waiting()`) whether some RUNNABLE process is in a higher queue. If so, the
  running process yields at that tick boundary. It keeps its queue and the ticks already used
  (`make_runnable(p, 0)`). This stops a process dodging demotion by being preempted repeatedly:
  in xv6 `pause()` wakes sleepers on every tick, which would otherwise reset the slice forever.
- **Priority boost.** In `clockintr()` (CPU 0), whenever `ticks % 48 == 0`, `mlfq_boost()` moves
  every process to queue 0 with `qticks = 0`. Their relative `qseq` order is kept.
- **Exit.** An exited process becomes ZOMBIE and is never RUNNABLE again, so it leaves all queues.
- **Ticks only.** Every decision above is made in the timer interrupt (`trap.c`), so preemption
  happens only at tick boundaries.
- **Event log.** Optional, with `MLFQLOG=1`: prints demotions, preemptions and boosts.

### Behaviour (`mlfqtest`: 2 CPU-bound + 1 I/O-bound, 1 CPU, `MLFQLOG=1`; preemption lines omitted)

```
[MLFQ] tick 12: PID 4 used full slice, Q0 -> Q1
[MLFQ] tick 13: PID 5 used full slice, Q0 -> Q1
[MLFQ] tick 20: PID 4 used full slice, Q1 -> Q2
[MLFQ] tick 21: PID 5 used full slice, Q1 -> Q2
[MLFQ] tick 36: PID 4 used full slice, Q2 -> Q3
[MLFQ] tick 37: PID 5 used full slice, Q2 -> Q3
[MLFQ] tick 48: priority boost, all processes -> Q0
[MLFQ] tick 48: PID 4 used full slice, Q0 -> Q1
[MLFQ] tick 49: PID 5 used full slice, Q0 -> Q1
...
mlfqtest: pid 6 done, rtime 0, wtime 122      <- I/O-bound: never demoted, stays in Q0
mlfqtest: pid 4 done, rtime 80, wtime 74
mlfqtest: pid 5 done, rtime 77, wtime 80
```

- The two CPU-bound processes sink one queue at a time. The gaps between demotions match the
  slice sizes: Q1 takes 4 + 4 ticks (12→20) and Q2 takes 8 + 8 ticks (20→36), since the two
  processes alternate.
- They take turns in Q3 until the boost at tick 48 (and again at 96, 144, …) lifts them back to Q0.
- The I/O-bound process never appears in a demotion line.
