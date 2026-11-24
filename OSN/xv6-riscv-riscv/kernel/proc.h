// Saved registers for kernel context switches.
struct context {
  uint64 ra;
  uint64 sp;

  // callee-saved
  uint64 s0;
  uint64 s1;
  uint64 s2;
  uint64 s3;
  uint64 s4;
  uint64 s5;
  uint64 s6;
  uint64 s7;
  uint64 s8;
  uint64 s9;
  uint64 s10;
  uint64 s11;
};

// Per-CPU state.
struct cpu {
  struct proc *proc;      // The process running on this cpu, or null.
  struct context context; // swtch() here to enter scheduler().
  int noff;               // Depth of push_off() nesting.
  int intena;             // Were interrupts enabled before push_off()?
};

extern struct cpu cpus[NCPU];

// per-process data for the trap handling code in trampoline.S.
// sits in a page by itself just under the trampoline page in the
// user page table. not specially mapped in the kernel page table.
// uservec in trampoline.S saves user registers in the trapframe,
// then initializes registers from the trapframe's
// kernel_sp, kernel_hartid, kernel_satp, and jumps to kernel_trap.
// prepare_return() and userret in trampoline.S set up
// the trapframe's kernel_*, restore user registers from the
// trapframe, switch to the user page table, and enter user space.
struct trapframe {
  /*   0 */ uint64 kernel_satp;   // kernel page table
  /*   8 */ uint64 kernel_sp;     // top of process's kernel stack
  /*  16 */ uint64 kernel_trap;   // usertrap()
  /*  24 */ uint64 epc;           // saved user program counter
  /*  32 */ uint64 kernel_hartid; // saved kernel tp
  /*  40 */ uint64 ra;
  /*  48 */ uint64 sp;
  /*  56 */ uint64 gp;
  /*  64 */ uint64 tp;
  /*  72 */ uint64 t0;
  /*  80 */ uint64 t1;
  /*  88 */ uint64 t2;
  /*  96 */ uint64 s0;
  /* 104 */ uint64 s1;
  /* 112 */ uint64 a0;
  /* 120 */ uint64 a1;
  /* 128 */ uint64 a2;
  /* 136 */ uint64 a3;
  /* 144 */ uint64 a4;
  /* 152 */ uint64 a5;
  /* 160 */ uint64 a6;
  /* 168 */ uint64 a7;
  /* 176 */ uint64 s2;
  /* 184 */ uint64 s3;
  /* 192 */ uint64 s4;
  /* 200 */ uint64 s5;
  /* 208 */ uint64 s6;
  /* 216 */ uint64 s7;
  /* 224 */ uint64 s8;
  /* 232 */ uint64 s9;
  /* 240 */ uint64 s10;
  /* 248 */ uint64 s11;
  /* 256 */ uint64 t3;
  /* 264 */ uint64 t4;
  /* 272 */ uint64 t5;
  /* 280 */ uint64 t6;
};

enum procstate { UNUSED, USED, SLEEPING, RUNNABLE, RUNNING, ZOMBIE };

// ############## LLM Generated Code Begins ##############
// A loadable ELF segment, kept so that exec can load pages on demand.
struct vmseg {
  uint64 vaddr;  // page-aligned start
  uint64 memsz;  // bytes in memory
  uint64 filesz; // bytes in the file (the rest is zero, e.g. bss)
  uint64 off;    // offset in the executable
  int perm;      // PTE_X and/or PTE_W
};
#define MAXVMSEG  8
#define NSWAPSLOT 1024 // max swap slots (4 MB) per process
// ############## LLM Generated Code Ends ################

// Per-process state
struct proc {
  struct spinlock lock;

  // p->lock must be held when using these:
  enum procstate state; // Process state
  void *chan;           // If non-zero, sleeping on chan
  int killed;           // If non-zero, have been killed
  int xstate;           // Exit status to be returned to parent's wait
  int pid;              // Process ID

  // wait_lock must be held when using this:
  struct proc *parent; // Parent process

  // these are private to the process, so p->lock need not be held.
  uint64 kstack;               // Virtual address of kernel stack
  uint64 sz;                   // Size of process memory (bytes)
  pagetable_t pagetable;       // User page table
  struct trapframe *trapframe; // data page for trampoline.S
  struct context context;      // swtch() here to run process
  struct file *ofile[NOFILE];  // Open files
  struct inode *cwd;           // Current directory
  char name[16];               // Process name (debugging)

  // Scheduling info
  uint ctime;                  // Tick at which the process was created (FCFS)
  uint rtime;                  // Ticks spent RUNNING (for waitx / report)
  uint etime;                  // Tick at which the process exited (for waitx)

  // CFS (p->lock must be held when using these)
  int nice;                    // -20 (highest priority) .. 19 (lowest)
  uint64 weight;               // 1024 / 1.25^nice, from prio_to_weight[]
  uint64 vruntime;             // weighted CPU time, in VRUNTIME_SCALE units per nice-0 tick
  int time_slice;              // ticks this process may run before preemption
  int slice_used;              // ticks used of the current time slice

  // MLFQ (p->lock must be held when using these)
  int queue;                   // current queue: 0 (highest) .. 3 (lowest)
  int qticks;                  // ticks used of the current queue's slice
  uint64 qseq;                 // when it joined its queue; lower = nearer the front

// ############## LLM Generated Code Begins ##############
  // Demand paging and swap (private to the process; see paging.c).
  struct inode *exec_ip;       // executable, for loading text/data on demand
  int nseg;                    // number of loadable ELF segments
  struct vmseg seg[MAXVMSEG];  // loadable ELF segments
  uint64 text_start, text_end; // for the INIT-LAZYMAP log
  uint64 data_start, data_end;
  uint64 stack_bottom;         // lowest stack page (just above the guard page)
  uint64 stack_top;            // top of the user stack = start of the heap
  uint next_seq;               // next FIFO sequence number
  struct inode *swap_ip;       // this process's swap file /pgswpXXXXX
  int swap_used;               // swap slots in use
  uchar swap_map[NSWAPSLOT / 8]; // bitmap of used swap slots
// ############## LLM Generated Code Ends ################
};

// MLFQ parameters
#define MLFQ_NQUEUE     4      // queues 0..3, slices 1, 4, 8, 16 ticks (mlfq_slice[] in proc.c)
#define BOOST_INTERVAL  48     // ticks; every 48 ticks all processes go back to queue 0

// CFS parameters
#define NICE_0_WEIGHT   1024   // weight of a nice-0 process
#define TARGET_LATENCY  48     // ticks; every runnable process should run once in this window
#define MIN_GRANULARITY 3      // ticks; smallest allowed time slice
#define VRUNTIME_SCALE  1000   // nice-0 process gains 1000 vruntime per tick (avoids fractions)
