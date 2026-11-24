# xv6: demand paging + swap (Mini Project 2, Part A) and schedulers (Mini Project 1)

## Mini Project 2, Part A: PagedOut Inc.

Demand paging, FIFO page replacement and per-process swap files for xv6-riscv. This is built on the
Mini Project 1 kernel below, so the schedulers still work. The two features are independent.

| Feature | Status |
|---|---|
| Demand paging: lazy `exec`, lazy `sbrk`, LOADEXEC / ALLOC on fault, invalid access kills | Done |
| Page replacement: per-process resident set, FIFO by sequence number, own pages only | Done |
| Swapping: `/pgswpXXXXX` per process, clean→DISCARD, dirty→SWAPOUT, SWAPIN, SWAPFULL, SWAPCLEANUP | Done |
| `memstat()` system call | Done |
| Bonus: alternative replacement policy (`PAGEREPL=CLEANFIFO`) | Done |

### Building and running

```bash
make clean; make qemu                          # default: 128 MB, FIFO
make clean; make qemu PHYSMEM=4 CPUS=1         # 4 MB of RAM: memory fills up fast (for testing)
make clean; make qemu PAGEREPL=CLEANFIFO       # bonus replacement policy
```

| Option | Values | Default | Effect |
|---|---|---|---|
| `PHYSMEM` | MB | `128` | RAM the kernel uses (`PHYSTOP`). Small values make replacement easy to test. |
| `PAGEREPL` | `FIFO`, `CLEANFIFO` | `FIFO` | Page replacement policy. |

The scheduler options (`SCHEDULER=...`) work as before.

Test programs:

```
$ lazytest            # lazy sbrk, ALLOC, dirty bits, memstat, 3 invalid accesses (killed children)
$ swaptest 1200 1     # with PHYSMEM=4: FIFO eviction, SWAPOUT/SWAPIN, all 1200 pages verified
$ swaptest 700 3      # 3 processes at once, each evicting only its own pages
$ swaptest 2500 1     # more than memory + 1024 slots: SWAPFULL, KILL swap-exhausted
```

### Design

**Address space.** It keeps the xv6 layout: `[text][data] [guard page] [stack] [heap → sz]`.
`exec()` records the ELF loadable segments, keeps a reference to the executable's inode, and maps **nothing**.
`stack_top` is the top of the one-page user stack. The heap starts there, so `heap_start = stack_top`.
`sbrk(n)` only changes `p->sz`. `sbrk(-n)` frees the removed pages and their swap slots.

**Page faults** (`vm_fault()` in `kernel/paging.c`) come from `usertrap()` (scause 12/13/15 → exec/read/write).
They also come from `copyin()`/`copyout()` when the kernel touches a non-resident user page.
The handler classifies the page in this order:

1. PTE marked swapped → `cause=swap` → read from the swap file → `SWAPIN`.
2. Inside an ELF segment → `cause=exec` → read the file part and zero the rest (bss) → `LOADEXEC`.
3. Inside the stack page and within one page below `sp` → `cause=stack` → zero-fill → `ALLOC`.
4. Between `stack_top` and `sz` → `cause=heap` → zero-fill → `ALLOC`.
5. Anything else is `KILL invalid-access`. That covers beyond `sz`, the guard page, kernel addresses,
   a write to text, and executing heap or stack.

A user process with an invalid access is killed. For the same bad pointer passed to a system call,
the call returns -1 as in stock xv6.

**Dirty bits** are tracked in software. Writable pages are mapped without `PTE_W`; a software bit `PTE_SWW`
marks them as writable. The first write traps, and the kernel sets `PTE_W` and marks the page dirty. No log
line is printed, because the page is already resident. A write fault on a new page maps it dirty at once.

**Frame table.** `frames[]` has one entry per physical frame: owner process, va, FIFO `seq`, dirty, and
"backed" (whether the page can be rebuilt from the executable or as zeros). A process's resident set is the
frames it owns. `kfree()` clears the entry, so frames freed anywhere leave the set.

**Replacement** happens only when `kalloc()` returns 0 inside a fault (`getframe()`/`walk_alloc()`).
The faulting process evicts **its own** page with the lowest sequence number.
Each process has a `next_seq` counter that wraps at 2^31. Victims are compared by
`(next_seq - seq) mod 2^31` (age), so wraparound does not break FIFO order.

**Eviction.**
- A clean page that is backed is dropped (`DISCARD`). The next fault rebuilds it with LOADEXEC (text/data) or ALLOC (zero heap/stack).
- A dirty page, or one with no other copy, is written to swap (`SWAPOUT`). Example: a page swapped in earlier, whose slot was then freed.
- The swapped PTE keeps `PTE_V=0`, `PTE_SWAP=1`, the slot number in the PPN field, and the original permissions.

**Swap file.**
- `/pgswpXXXXX` (5-digit PID) in the root directory, made of ordinary file blocks.
- It is created in `exec()` (emptied if the process already had one) and by `fork()` for the child.
- It is deleted in `exit()`, which prints `SWAPCLEANUP freed_slots=K` with the slots still in use.
- A 1024-bit bitmap tracks free slots. Each slot is 4096 bytes at offset `slot*4096`, allocated lowest-free first. A slot is freed on SWAPIN.
- If no slot is free when a dirty page must be evicted, the kernel prints `SWAPFULL`, then `KILL swap-exhausted`, and kills the process.

**fork()** (not specified by the project). The child gets its own swap file. Resident pages are copied
with their sequence numbers, or written to the child's swap if memory is full. Swapped pages are copied
slot to slot. The child inherits the parent's executable reference.

**File system changes needed for 4 MB swap files.**
- Stock xv6 files are at most 268 KB, so the inode now has 11 direct blocks, 1 indirect and 1 doubly-indirect block.
  Only 16 entries of the doubly-indirect block are used, so `MAXFILE` is 4363 blocks (≈4.3 MB): enough for a full swap file (4096 blocks), small enough for usertests' `writebig`.
- `FSSIZE` is 40000 blocks (40 MB) so several swap files fit.
- Each swap write uses two half-page log transactions, to stay under `MAXOPBLOCKS`.

**Locking.** Loading a page may sleep for disk I/O. The fault path therefore turns interrupts on, as for system calls.
Some `copyin`/`copyout` calls run with a spinlock held (pipes, console, `wait`). For these,
`read()`, `write()`, `wait()` and `waitx()` fault the user buffer in first (`vm_prefault()`).
If a copy still needs I/O with a spinlock held, it fails instead of sleeping.

### Log lines

Printed with `printk` exactly in the required formats. Addresses are page-aligned lowercase hex.

```
[pid X] INIT-LAZYMAP text=[0xA,0xB) data=[0xC,0xD) heap_start=0xE stack_top=0xF
[pid X] PAGEFAULT va=0xV access=<read|write|exec> cause=<heap|stack|exec|swap>
[pid X] ALLOC va=0xV | LOADEXEC va=0xV | SWAPIN va=0xV slot=N
[pid X] RESIDENT va=0xV seq=S
[pid X] MEMFULL
[pid X] VICTIM va=0xV seq=S algo=FIFO
[pid X] EVICT  va=0xV state=<clean|dirty>        (two spaces, as in the spec)
[pid X] DISCARD va=0xV | SWAPOUT va=0xV slot=N
[pid X] KILL invalid-access va=0xV access=<...>
[pid X] SWAPFULL / [pid X] KILL swap-exhausted
[pid X] SWAPCLEANUP freed_slots=K
```

Orderings follow the spec, e.g. `PAGEFAULT → MEMFULL → VICTIM → EVICT → SWAPOUT → ALLOC → RESIDENT`.
`exec` copies the arguments onto the new stack, so a process's first fault after `INIT-LAZYMAP`
is its stack page, followed by the faults on text and data.

### `memstat()`

```c
#include "kernel/memstat.h"
int memstat(struct proc_mem_stat *info);   // 0 on success, -1 on a bad pointer
```

- It reports every page in `[0, sz)`: `num_pages_total`, resident and swapped counts, `next_fifo_seq`.
- It lists the lowest 128 pages in `pages[]`. Unused entries are zeroed.
- Unmapped pages have `seq=-1`, `swap_slot=-1`.
- A swapped page's `is_dirty` says whether it was dirty when evicted.

### Bonus: `CLEANFIFO` replacement (`make PAGEREPL=CLEANFIFO`)

**Algorithm.** Among the faulting process's resident pages, evict the **oldest clean, backed page**
(lowest seq among pages that can be discarded without disk I/O), but only one in the **older half** of the FIFO queue.
That means its age is at least half the age of the oldest page. If there is no such page, evict the oldest page (plain FIFO).
The log reads `VICTIM va=... seq=S algo=CLEANFIFO`.

**Rationale.**
- Under FIFO, every dirty victim costs a disk write, and anonymous pages always need a swap slot.
- CLEANFIFO first drops pages that are free to drop: text pages and untouched zero pages. That saves disk writes and keeps swap slots for data that needs them.
- Within each class it is still FIFO, so it is simple and predictable.
- Why "older half": without that rule, a program whose only clean page is its text page thrashed.
  Every swap-in evicted the text page, and the next instruction fetch reloaded it at once.
  With `swaptest 1200` at 4 MB, that run did not finish in 500 s.
  With the rule, a page that was just reloaded is young and safe, and the same run takes about a minute with 15 LOADEXECs.
- Trade-off: hot text pages can still be dropped once they reach the older half, so a program that cycles through
  a large clean working set can take more LOADEXEC faults than under FIFO.
- It also cannot tell hot pages from cold ones (no reference bits), like FIFO.

**Implementation.**
- `pick_victim()` makes two passes over the frame table, using the same wraparound-safe age.
- The first pass finds the process's oldest frame. The second finds the oldest frame with `dirty==0 && backed==1` and age ≥ half of that.
- It returns the clean one if one exists.
- Everything else is shared with FIFO: only the faulting process's frames are scanned, clean pages are discarded, dirty pages are swapped, and swap-full handling is unchanged.
- Edge cases:
  - A page swapped back in is clean but not backed, so CLEANFIFO does not treat it as free to drop.
  - Forked children inherit the parent's dirty and backed flags.

### Files changed for Part A

| File | Changes |
|---|---|
| `kernel/paging.c` (new) | Frame table, fault handler, FIFO/CLEANFIFO eviction, swap file create/delete/read/write, `vm_exec`, `vm_fork`, `vm_free`, `vm_shrink`, `vm_prefault`, `vm_memstat`. |
| `kernel/memstat.h` (new) | `struct page_stat`, `struct proc_mem_stat`. |
| `kernel/exec.c` | Lazy exec: records segments, maps nothing, keeps the inode; arguments copied after commit. |
| `kernel/trap.c` | Page faults go to `vm_fault()`. |
| `kernel/vm.c` | `vmfault()` → `vm_fault()`; `copyout()` handles clean writable pages. |
| `kernel/proc.c`, `proc.h` | Paging fields in `struct proc`; lazy `growproc()`; `kfork()` uses `vm_fork()`; `kexit()` calls `vm_free()`. |
| `kernel/kalloc.c` | `kfree()` clears the frame-table entry. |
| `kernel/sysproc.c`, `sysfile.c` | Lazy `sbrk`; `sys_memstat`; prefaulting in `read`/`write`/`wait`/`waitx`. |
| `kernel/fs.c`, `fs.h`, `file.h`, `param.h` | Doubly-indirect blocks; `FSSIZE` 40000. |
| `kernel/riscv.h`, `memlayout.h`, `defs.h` | `PTE_SWW`, `PTE_SWAP`; `PHYSMEM_MB`; prototypes. |
| `kernel/syscall.[ch]`, `user/user.h`, `user/usys.pl` | Syscall 26 `memstat`. |
| `user/lazytest.c`, `user/swaptest.c` (new), `Makefile` | Tests; `PHYSMEM` and `PAGEREPL` options. |

### Assumptions

- The INIT-LAZYMAP ranges are page-rounded segment bounds. `heap_start` equals `stack_top` because the heap starts right above the stack.
- The `cause` for an invalid address is the region it falls in: `heap` above `stack_top`, `stack` for the stack and guard page, `exec` below.
- The `MEMFULL` line is printed before each eviction.
- If a process has nothing of its own to evict, it is killed without a special log line. No format exists for that case.
- Forked children get their own swap file (the spec only mentions exec).
- `sbrk()` is always lazy, as the spec requires. Stock `usertests` assumes an eager `sbrk()`: its `countfree()` grows the heap until `sbrk` fails, which never happens with a lazy `sbrk`.
  So `usertests` can only be run with `sbrk` temporarily made eager again.

---

# Mini Project 1: `getreadcount` syscall and FCFS / CFS / MLFQ schedulers

Changes to xv6-riscv for Mini Project 1 (CS3301 Operating Systems and Networks):

| Part | Feature | Status |
|---|---|---|
| A | `getreadcount()` system call + `readcount` user program | Done |
| B | FCFS scheduler (non-preemptive) | Done |
| B | CFS scheduler: nice/weight, vruntime, lowest-vruntime selection, time slices, logging | Done |
| Report | RR vs FCFS vs CFS (vs MLFQ) comparison, using `waitx` + `schedulertest` | Done, see [report.md](report.md) |
| Bonus | Preemptive MLFQ (4 queues, demotion, priority boost) | Done |

The original xv6 README is kept unchanged in [README](README).

---

## Requirements

Ubuntu 24.04 (or similar):

```bash
sudo apt install build-essential gcc-riscv64-linux-gnu binutils-riscv64-linux-gnu qemu-system-misc
```

---

## Building and running

The scheduler is chosen **at compile time** with `SCHEDULER`. Round Robin is the default.
Run `make clean` every time you switch, so that every file is rebuilt with the new setting.

```bash
make clean; make qemu                        # Round Robin (default xv6 scheduler)
make clean; make qemu SCHEDULER=FCFS         # First Come First Serve
make clean; make qemu SCHEDULER=CFS          # Completely Fair Scheduler (vruntime log ON)
make clean; make qemu SCHEDULER=MLFQ         # Multi-Level Feedback Queue (bonus)
```

| Option | Values | Default | Effect |
|---|---|---|---|
| `SCHEDULER` | `RR`, `FCFS`, `CFS`, `MLFQ` | `RR` | Selects the scheduling policy. Any other value stops the build with an error. |
| `CFSLOG` | `1`, `0` | `1` | CFS only: prints the `[Scheduler Tick]` vruntime log before every decision. |
| `MLFQLOG` | `0`, `1` | `0` | MLFQ only: prints queue events (demotions, preemptions, boosts). |
| `CPUS` | number | `3` | Number of CPUs. Use `CPUS=1` to compare schedulers. |

Examples:

```bash
make clean; make qemu CPUS=1 SCHEDULER=CFS CFSLOG=0     # CFS without the log
make clean; make qemu CPUS=1 SCHEDULER=MLFQ MLFQLOG=1   # MLFQ with the event log
```

Exit QEMU with `Ctrl-A` then `X`. Press `Ctrl-P` inside xv6 for a process listing, which shows
the new scheduling fields (`ctime rtime nice vruntime slice q`).

---

## Part A: `getreadcount`

```c
int getreadcount(void);   // total bytes returned by read() across all processes since boot
```

- A global counter in `kernel/sysfile.c` is increased inside `sys_read()` by the number of bytes
  `fileread()` actually returned (errors and EOF add nothing).
- The increase is atomic (`__sync_fetch_and_add`), so reads on several CPUs at once are all counted.
- The counter is a 32-bit `uint`, so it wraps back to 0 on overflow.

**User program:** `readcount [file]` (the default file is `README`)

```
$ readcount
Initial read count: 10
Read 100 bytes from README
Read count after read: 110
Increase: 100 bytes
OK: read count increased by 100 as expected
```

The starting value is not 0, because the counter also includes the reads made while booting
(`init`, `sh`).

---

## Part B: Schedulers

All policies share one structure:
- `scheduler()` in `kernel/proc.c` has one `#if` branch per policy. The original Round Robin code
  is kept, unchanged, as the `#else` branch.
- Both timer-interrupt paths in `kernel/trap.c` call `sched_tick()`. It does the per-tick
  accounting and decides whether the running process must give up the CPU.

| Policy | Next process to run | When the running process is preempted |
|---|---|---|
| RR | Next RUNNABLE entry in the process table | Every tick |
| FCFS | Earliest creation time (`ctime`), ties → lower pid | Never (runs until it exits or blocks) |
| CFS | Lowest `vruntime`, ties → lower pid | When its time slice `max(48 / N, 3)` ticks is used up |
| MLFQ | Highest non-empty queue, then first to join that queue | At the end of its slice (1/4/8/16 ticks), or when a higher-queue process is waiting |

### FCFS
- `allocproc()` records `ctime = ticks` for every new process.
- The scheduler runs the RUNNABLE process with the smallest `ctime`.
- Under FCFS, `sched_tick()` never asks for preemption.

### CFS
- **Priority:** `nice` ranges from −20 to 19, defaults to 0 and is inherited on `fork`. The weight
  is `1024 / 1.25^nice`, read from a 40-entry table: nice −20 = 88761, 0 = 1024, 19 = 15.
- **vruntime:** starts at 0. Each tick the running process gains `1000 × 1024 / weight`, so
  vruntime is measured in thousandths of a nice-0 tick. The ×1000 keeps the per-tick increase
  above 0 even for heavy weights.
- **Selection:** the RUNNABLE process with the lowest vruntime.
- **Time slice:** `48 / N` ticks, where N is the number of RUNNABLE processes, but at least 3.
- **Log format** (with `CFSLOG=1`):
  ```
  [Scheduler Tick]
  PID: 4 | vRuntime: 148944
  PID: 5 | vRuntime: 16000
  PID: 6 | vRuntime: 1712
  --> Scheduling PID 6 (lowest vRuntime)
  ```

### MLFQ (bonus)
- 4 queues with time slices of 1, 4, 8 and 16 ticks. New processes join the end of queue 0.
- A process that uses its full slice moves to the end of the next lower queue. In queue 3 it stays
  in queue 3, so queue 3 works as round robin.
- A process that blocks (I/O, sleep) before its slice ends joins the end of the same queue when it
  wakes up.
- A RUNNABLE process in a higher queue preempts the running process at the next tick. The
  preempted process keeps the ticks it has already used, so it cannot dodge demotion.
- Every 48 ticks, every process moves back to queue 0 (starvation prevention).

Implementation details and design choices are explained in [report.md](report.md).

---

## New system calls

| # | Call | Purpose |
|---|---|---|
| 23 | `int getreadcount(void)` | Part A: total bytes read since boot. |
| 24 | `int setnice(int pid, int nice)` | Sets a process's CFS priority (−20..19). Returns 0, or −1 if the value is out of range or the pid doesn't exist. |
| 25 | `int waitx(int *status, int *wtime, int *rtime)` | Like `wait()`, but also returns the child's running time and waiting time in ticks (`wtime = exit − creation − running`). Used by `schedulertest`. |

---

## User programs

| Program | Purpose |
|---|---|
| `readcount [file]` | Part A test: shows the read counter increasing by the number of bytes read. |
| `schedulertest` | Report benchmark: 5 I/O-bound and 5 CPU-bound children. Prints `Average rtime X,  wait time Y`. |
| `fcfstest` | 3 CPU-bound children. Under FCFS they run strictly one after another. |
| `cfstest` | 3 CPU-bound children with nice 10 / 0 / −10. Under CFS, nice −10 finishes first. |
| `mlfqtest` | 2 CPU-bound + 1 I/O-bound child. With `MLFQLOG=1`, shows Q0→Q3 demotion, round robin in Q3, the I/O-bound child staying in Q0, and the boost every 48 ticks. |

`user/ulib.c` also gets `sleep(n)`, a thin wrapper for this xv6's `pause(n)` (newer xv6 renamed
`sleep`), so the standard `schedulertest` source compiles unchanged.

---

## Performance summary

`schedulertest`, `CPUS=1`, logs off, average of 3 runs (ticks):

| Scheduler | Avg running time | Avg waiting time |
|---|---|---|
| Round Robin | 9 | 137.7 |
| FCFS | 9.7 | 119 |
| CFS | 9.7 | 137.7 |
| MLFQ | 9 | 136.7 |

Full results and analysis are in [report.md](report.md).

---

## Files modified

| File | Changes |
|---|---|
| `Makefile` | `SCHEDULER`, `CFSLOG` and `MLFQLOG` options; new user programs added to `UPROGS`. |
| `kernel/proc.h` | New `struct proc` fields: `ctime`, `rtime`, `etime`, `nice`, `weight`, `vruntime`, `time_slice`, `slice_used`, `queue`, `qticks`, `qseq`; CFS/MLFQ constants. |
| `kernel/proc.c` | Field initialisation in `allocproc()`; nice inherited in `kfork()`; `etime` set in `kexit()`; `make_runnable()` helper; nice→weight table and `setnice()`; `sched_tick()`; `kwaitx()`; MLFQ `mlfq_higher_waiting()` / `mlfq_boost()`; FCFS/CFS/MLFQ branches of `scheduler()`; extended `procdump()`. |
| `kernel/trap.c` | Timer interrupts call `sched_tick()` to decide on `yield()`; MLFQ priority boost in `clockintr()`. |
| `kernel/sysfile.c` | Read counter in `sys_read()`; `sys_getreadcount()`. |
| `kernel/sysproc.c` | `sys_setnice()`, `sys_waitx()`. |
| `kernel/syscall.h`, `kernel/syscall.c` | Syscall numbers 23–25 and their table entries. |
| `kernel/defs.h` | Prototypes for the new kernel functions. |
| `user/user.h`, `user/usys.pl` | User-side declarations and stubs for the new syscalls. |
| `user/ulib.c` | `sleep()` wrapper. |
| `user/readcount.c`, `schedulertest.c`, `fcfstest.c`, `cfstest.c`, `mlfqtest.c` | New user programs. |

Generate the patch against stock xv6, including the new files:

```bash
git add -N user/*.c && git diff > xv6_modifications.patch
```

---

## Assumptions and notes

- **Ticks.** All times are in timer ticks (about 0.1 s each, one clock interrupt in `kernel/trap.c`).
  Preemption happens only at tick boundaries.
- **Waiting time.** Waiting time from `waitx` counts every tick the process existed but was not
  running, including time spent sleeping.
- **CFS run queue.** CFS finds the lowest-vruntime process by scanning the process table at each
  decision (at most `NPROC = 64` entries). This always selects the same process as the head of a
  vruntime-sorted queue would.
- **New processes and vruntime.** As the spec requires, new processes start at vruntime 0.
  Waking from sleep keeps vruntime, and a wake-up does not preempt the running slice.
- **`schedulertest` source.** The course's `schedulertest` link requires an IIIT login, so
  `user/schedulertest.c` is the standard version of the test (10 children: 5 × `sleep(200)`,
  5 × busy loop, timed with `waitx`).
- **Multiple CPUs.** Every policy runs on multiple CPUs, and each CPU makes its own scheduling
  decisions. xv6's `usertests` pass under RR, CFS and MLFQ on 3 CPUs. Scheduler comparisons
  should be run with `CPUS=1`.
- **Logs.** The CFS log is meant to be read with `CPUS=1`. With several CPUs the lines from
  different CPUs interleave.

---

## LLM usage

Parts of this code and documentation were produced with the help of an LLM. As required by the
course, LLM-generated code is marked with
`############## LLM Generated Code Begins ##############` / `############## LLM Generated Code Ends ################`,
and the prompts and responses are included as screenshots in `llm_completions/`.
