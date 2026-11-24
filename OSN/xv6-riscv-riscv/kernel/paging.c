// ############## LLM Generated Code Begins ##############
// Demand paging, page replacement and per-process swap files.
//
// - exec() and sbrk() map nothing. Every user page is brought in by a
//   page fault: text/data pages are read from the executable (LOADEXEC),
//   heap and stack pages are zero-filled (ALLOC), and swapped-out pages
//   are read back from the process's swap file (SWAPIN).
// - Every physical frame that holds a user page has an entry in frames[]
//   (owner, va, FIFO sequence number, dirty bit). A process's resident
//   set is the set of frames it owns.
// - When kalloc() fails during a fault, the faulting process evicts one of
//   ITS OWN resident pages (FIFO: lowest sequence number, or CLEANFIFO,
//   see pick_victim()). Clean pages that can be rebuilt are dropped;
//   other pages are written to the swap file /pgswpXXXXX (PID based).
// - Dirty tracking is done in software: a writable page is mapped
//   without PTE_W (and with PTE_SWW) until the first write traps.
//
// Swapped-out PTEs have PTE_V clear, PTE_SWAP set and the swap slot in
// the PPN field, so the hardware ignores them.

#include "types.h"
#include "param.h"
#include "memlayout.h"
#include "riscv.h"
#include "spinlock.h"
#include "sleeplock.h"
#include "proc.h"
#include "defs.h"
#include "fs.h"
#include "file.h"
#include "stat.h"
#include "memstat.h"

#define NFRAME  ((PHYSTOP - KERNBASE) / PGSIZE)
#define SEQMASK 0x7fffffff // seq numbers stay non-negative and wrap here

// Replacement policy name for the VICTIM log (make PAGEREPL=...).
#ifdef CLEANFIFO
#define ALGO "CLEANFIFO"
#else
#define ALGO "FIFO"
#endif

// The spec's EVICT format has two spaces after "EVICT".
#define EVICT_FMT "[pid %d] EVICT  va=0x%lx state=%s\n"

static char *accname[] = {[ACC_READ] "read", [ACC_WRITE] "write",
                          [ACC_EXEC] "exec"};
enum { C_HEAP, C_STACK, C_EXEC, C_SWAP };
static char *causename[] = {[C_HEAP] "heap", [C_STACK] "stack",
                            [C_EXEC] "exec", [C_SWAP] "swap"};

// One entry per physical frame.
struct frame {
  struct proc *owner; // process whose user page this is, or 0
  uint64 va;          // user virtual address of the page
  uint seq;           // FIFO sequence number when it became resident
  uchar dirty;        // written since it became resident
  uchar backed;       // can be rebuilt without swap (executable / zero)
};
static struct frame frames[NFRAME];
static struct spinlock framelock;

static struct frame *
pa2frame(uint64 pa)
{
  return &frames[(pa - KERNBASE) / PGSIZE];
}

static uint64
frame2pa(struct frame *f)
{
  return KERNBASE + (uint64)(f - frames) * PGSIZE;
}

void
frameinit(void)
{
  initlock(&framelock, "frames");
}

// Called by kfree(): the frame no longer holds a user page.
void
frame_clear(uint64 pa)
{
  acquire(&framelock);
  pa2frame(pa)->owner = 0;
  release(&framelock);
}

static void
frame_add(struct proc *p, uint64 pa, uint64 va, uint seq, int dirty,
          int backed)
{
  acquire(&framelock);
  struct frame *f = pa2frame(pa);
  f->owner = p;
  f->va = va;
  f->seq = seq;
  f->dirty = dirty;
  f->backed = backed;
  release(&framelock);
}

// Is the caller holding no spinlocks (so it may sleep for disk I/O)?
static int
cansleep(void)
{
  push_off();
  int ok = (mycpu()->noff == 1);
  pop_off();
  return ok;
}

// ---------------------------------------------------------------------
// Swap slots and the swap file.

static int
slot_alloc(struct proc *p)
{
  // Lowest free slot. This keeps the file dense: slots below the one
  // returned are in use, so they were written and the file is at least
  // that long (writei() cannot write past the end of a file).
  for (int i = 0; i < NSWAPSLOT; i++) {
    if ((p->swap_map[i / 8] & (1 << (i % 8))) == 0) {
      p->swap_map[i / 8] |= (1 << (i % 8));
      p->swap_used++;
      return i;
    }
  }
  return -1;
}

static void
slot_free(struct proc *p, int slot)
{
  if (slot < 0 || slot >= NSWAPSLOT ||
      (p->swap_map[slot / 8] & (1 << (slot % 8))) == 0)
    panic("slot_free");
  p->swap_map[slot / 8] &= ~(1 << (slot % 8));
  p->swap_used--;
}

// "/pgswp" followed by the pid in 5 digits, e.g. /pgswp00023.
static void
swapname(int pid, char *buf)
{
  safestrcpy(buf, "/pgswp", 16);
  for (int i = 10; i >= 6; i--) {
    buf[i] = '0' + pid % 10;
    pid /= 10;
  }
  buf[11] = 0;
}

// Create (or empty, if left over from an earlier boot) the swap file of
// process pid in the root directory. Returns an unlocked, referenced
// inode, or 0.
static struct inode *
swap_create(int pid)
{
  char path[16], name[DIRSIZ];
  struct inode *dp, *ip;

  swapname(pid, path);
  begin_op();
  if ((dp = nameiparent(path, name)) == 0) {
    end_op();
    return 0;
  }
  ilock(dp);
  if ((ip = dirlookup(dp, name, 0)) != 0) {
    iunlockput(dp);
    ilock(ip);
    if (ip->type != T_FILE) {
      iunlockput(ip);
      end_op();
      return 0;
    }
    itrunc(ip);
    iunlock(ip);
    end_op();
    return ip;
  }
  if ((ip = ialloc(dp->dev, T_FILE)) == 0) {
    iunlockput(dp);
    end_op();
    return 0;
  }
  ilock(ip);
  ip->major = 0;
  ip->minor = 0;
  ip->nlink = 1;
  iupdate(ip);
  if (dirlink(dp, name, ip->inum) < 0) {
    ip->nlink = 0;
    iupdate(ip);
    iunlockput(ip);
    iunlockput(dp);
    end_op();
    return 0;
  }
  iunlockput(dp);
  iunlock(ip);
  end_op();
  return ip;
}

// Remove p's swap file from the root directory and drop our reference,
// which frees its blocks.
static void
swap_delete(struct proc *p)
{
  char path[16], name[DIRSIZ];
  struct inode *ip = p->swap_ip, *dp, *dip;
  struct dirent de;
  uint off;

  if (ip == 0)
    return;
  p->swap_ip = 0;
  swapname(p->pid, path);
  begin_op();
  if ((dp = nameiparent(path, name)) != 0) {
    ilock(dp);
    if ((dip = dirlookup(dp, name, &off)) != 0) {
      if (dip == ip) {
        memset(&de, 0, sizeof(de));
        if (writei(dp, 0, (uint64)&de, off, sizeof(de)) != sizeof(de))
          panic("swap_delete");
        ilock(ip);
        ip->nlink--;
        iupdate(ip);
        iunlock(ip);
      }
      iput(dip);
    }
    iunlockput(dp);
  }
  iput(ip);
  end_op();
}

// Write one page (kernel address src) to a swap slot.
// Two half-page transactions keep each one well under MAXOPBLOCKS.
#define SWAPCHUNK (PGSIZE / 2)
static int
swap_write(struct proc *p, int slot, uint64 src)
{
  struct inode *ip = p->swap_ip;
  uint off = slot * PGSIZE;

  if (ip == 0)
    return -1;
  for (int i = 0; i < PGSIZE; i += SWAPCHUNK) {
    begin_op();
    ilock(ip);
    int n = writei(ip, 0, src + i, off + i, SWAPCHUNK);
    iunlock(ip);
    end_op();
    if (n != SWAPCHUNK)
      return -1;
  }
  return 0;
}

// Read one page from a swap slot of p's swap file into kernel address dst.
static int
swap_read(struct inode *ip, int slot, uint64 dst, uint n, uint off)
{
  if (ip == 0)
    return -1;
  ilock(ip);
  int r = readi(ip, 0, dst, slot * PGSIZE + off, n);
  iunlock(ip);
  return r == n ? 0 : -1;
}

// ---------------------------------------------------------------------
// Page replacement.

// Choose a victim among p's resident pages. Caller holds framelock.
static struct frame *
pick_victim(struct proc *p)
{
  struct frame *best = 0;
  uint bestage = 0;

  for (struct frame *f = frames; f < &frames[NFRAME]; f++) {
    if (f->owner != p)
      continue;
    // Age relative to the next sequence number; correct across wraparound.
    uint age = (p->next_seq - f->seq) & SEQMASK;
    if (best == 0 || age > bestage) {
      best = f;
      bestage = age;
    }
  }
#ifdef CLEANFIFO
  // Bonus policy: the oldest page that can be dropped without disk I/O
  // (clean and rebuildable), but only from the older half of the FIFO
  // queue (age >= half the oldest page's age). A page that was just
  // brought back is young, so it is not evicted again straight away.
  // If there is no such page, plain FIFO.
  struct frame *bestclean = 0;
  uint cleanage = 0;
  for (struct frame *f = frames; best && f < &frames[NFRAME]; f++) {
    if (f->owner != p || f->dirty || !f->backed)
      continue;
    uint age = (p->next_seq - f->seq) & SEQMASK;
    if (age >= bestage / 2 && (bestclean == 0 || age > cleanage)) {
      bestclean = f;
      cleanage = age;
    }
  }
  if (bestclean)
    return bestclean;
#endif
  return best;
}

// Evict one of p's resident pages.
// Returns 0 if a frame was freed, -1 if p has nothing to evict,
// -2 if p was killed because its swap is full.
static int
evict(struct proc *p)
{
  acquire(&framelock);
  struct frame *f = pick_victim(p);
  if (f == 0) {
    release(&framelock);
    return -1;
  }
  uint64 va = f->va;
  uint seq = f->seq;
  int dirty = f->dirty, backed = f->backed;
  f->owner = 0; // out of the resident set
  release(&framelock);

  uint64 pa = frame2pa(f);
  pte_t *pte = walk(p->pagetable, va, 0);
  if (pte == 0 || (*pte & PTE_V) == 0 || PTE2PA(*pte) != pa)
    panic("evict: bad victim");

  printk("[pid %d] VICTIM va=0x%lx seq=%d algo=%s\n", p->pid, va, (int)seq,
         ALGO);
  printk(EVICT_FMT, p->pid, va, dirty ? "dirty" : "clean");

  if (!dirty && backed) {
    // Its contents are still in the executable (or it is all zeros):
    // the next fault rebuilds it.
    printk("[pid %d] DISCARD va=0x%lx\n", p->pid, va);
    *pte = 0;
  } else {
    int slot = slot_alloc(p);
    if (slot >= 0 && swap_write(p, slot, pa) < 0) {
      slot_free(p, slot); // disk full: same as no slot
      slot = -1;
    }
    if (slot < 0) {
      printk("[pid %d] SWAPFULL\n", p->pid);
      printk("[pid %d] KILL swap-exhausted\n", p->pid);
      frame_add(p, pa, va, seq, dirty, backed); // still resident
      setkilled(p);
      return -2;
    }
    printk("[pid %d] SWAPOUT va=0x%lx slot=%d\n", p->pid, va, slot);
    uint64 flags = *pte & (PTE_R | PTE_X | PTE_U | PTE_SWW);
    if (*pte & PTE_W)
      flags |= PTE_SWW;
    if (dirty)
      flags |= PTE_D; // remembered only for memstat
    *pte = SLOT2PTE(slot) | flags | PTE_SWAP;
  }
  sfence_vma();
  kfree((void *)pa);
  return 0;
}

// Allocate a frame for p, evicting p's own pages while memory is full.
// Returns 0 (and marks p killed) if that is impossible.
static uint64
getframe(struct proc *p)
{
  for (;;) {
    void *mem = kalloc();
    if (mem)
      return (uint64)mem;
    if (!cansleep())
      return 0; // caller holds a spinlock; just fail this access
    printk("[pid %d] MEMFULL\n", p->pid);
    int r = evict(p);
    if (r == -1)
      setkilled(p); // out of memory and nothing of its own to evict
    if (r < 0)
      return 0;
  }
}

// walk(..., alloc=1), evicting p's pages if a page-table page is needed
// and memory is full.
static pte_t *
walk_alloc(struct proc *p, uint64 va)
{
  for (;;) {
    pte_t *pte = walk(p->pagetable, va, 1);
    if (pte)
      return pte;
    if (!cansleep())
      return 0;
    printk("[pid %d] MEMFULL\n", p->pid);
    int r = evict(p);
    if (r == -1)
      setkilled(p);
    if (r < 0)
      return 0;
  }
}

// ---------------------------------------------------------------------
// Page faults.

static struct vmseg *
findseg(struct proc *p, uint64 va)
{
  for (int i = 0; i < p->nseg; i++) {
    struct vmseg *s = &p->seg[i];
    if (va >= s->vaddr && va < PGROUNDUP(s->vaddr + s->memsz))
      return s;
  }
  return 0;
}

// Which region an (invalid) address is in, for the PAGEFAULT log.
static int
region_cause(struct proc *p, uint64 va)
{
  if (va >= p->stack_top)
    return C_HEAP;
  if (va + PGSIZE >= p->stack_bottom) // stack or its guard page
    return C_STACK;
  return C_EXEC;
}

// Read the file-backed part of page va from the executable into pa.
static int
load_exec_page(struct proc *p, uint64 va, uint64 pa)
{
  int ok = 1;

  memset((void *)pa, 0, PGSIZE);
  ilock(p->exec_ip);
  for (int i = 0; i < p->nseg; i++) {
    struct vmseg *s = &p->seg[i];
    uint64 lo = va > s->vaddr ? va : s->vaddr;
    uint64 hi = va + PGSIZE;
    if (hi > s->vaddr + s->filesz)
      hi = s->vaddr + s->filesz;
    if (lo >= hi)
      continue;
    uint n = hi - lo;
    if (readi(p->exec_ip, 0, pa + (lo - va), s->off + (lo - s->vaddr), n) != n)
      ok = 0;
  }
  iunlock(p->exec_ip);
  return ok ? 0 : -1;
}

// Handle a fault at va in process p.
// access: ACC_READ, ACC_WRITE or ACC_EXEC.
// user:   1 for a hardware page fault from user mode; 0 for a kernel
//         access through copyin()/copyout(). An invalid kernel access just
//         fails (the system call returns -1) instead of killing.
// Returns the physical address of the page, or 0 on failure.
uint64
vm_fault(struct proc *p, uint64 va, int access, int user)
{
  int cause, valid = 1;
  struct vmseg *s = 0;
  pte_t *pte = 0;

  uint64 va0 = PGROUNDDOWN(va);
  if (va0 < MAXVA)
    pte = walk(p->pagetable, va0, 0);

  if (pte && (*pte & PTE_V)) {
    // The page is resident.
    if ((*pte & PTE_U) && access == ACC_WRITE && (*pte & PTE_SWW)) {
      // First write to a clean writable page: now it is dirty.
      *pte = (*pte & ~PTE_SWW) | PTE_W | PTE_D;
      sfence_vma();
      acquire(&framelock);
      pa2frame(PTE2PA(*pte))->dirty = 1;
      release(&framelock);
      return PTE2PA(*pte);
    }
    if ((*pte & PTE_U) && !(access == ACC_WRITE && !(*pte & PTE_W)) &&
        !(access == ACC_EXEC && !(*pte & PTE_X)))
      return PTE2PA(*pte); // nothing to do (stale TLB entry)
    cause = region_cause(p, va0); // e.g. a write to the text segment
    valid = 0;
  } else if (pte && (*pte & PTE_SWAP)) {
    cause = C_SWAP;
    if ((access == ACC_WRITE && !(*pte & PTE_SWW)) ||
        (access == ACC_EXEC && !(*pte & PTE_X)))
      valid = 0;
  } else if (va0 >= MAXVA || va0 >= p->sz) {
    cause = region_cause(p, va0);
    valid = 0;
  } else if ((s = findseg(p, va0)) != 0) {
    cause = C_EXEC;
    if ((access == ACC_WRITE && !(s->perm & PTE_W)) ||
        (access == ACC_EXEC && !(s->perm & PTE_X)))
      valid = 0;
  } else if (va0 >= p->stack_bottom && va0 < p->stack_top) {
    cause = C_STACK;
    // Valid only within one page below the current stack pointer.
    if (access == ACC_EXEC || va + PGSIZE < p->trapframe->sp)
      valid = 0;
  } else if (va0 >= p->stack_top) {
    cause = C_HEAP; // between stack_top and sz
    if (access == ACC_EXEC)
      valid = 0;
  } else {
    cause = region_cause(p, va0); // guard page or a gap
    valid = 0;
  }

  if (!user) {
    if (!valid)
      return 0;
    // copyin/copyout called with a spinlock held cannot sleep for I/O.
    if ((cause == C_SWAP || cause == C_EXEC) && !cansleep())
      return 0;
  }

  printk("[pid %d] PAGEFAULT va=0x%lx access=%s cause=%s\n", p->pid, va0,
         accname[access], causename[cause]);

  if (!valid) {
    printk("[pid %d] KILL invalid-access va=0x%lx access=%s\n", p->pid, va0,
           accname[access]);
    setkilled(p);
    return 0;
  }

  // Page-table pages first, then the frame, so that any eviction is logged
  // before ALLOC/LOADEXEC/SWAPIN.
  if ((pte = walk_alloc(p, va0)) == 0)
    return 0;
  uint64 mem = getframe(p);
  if (mem == 0)
    return 0;

  uint64 perm;
  int backed;
  if (cause == C_SWAP) {
    int slot = PTE2SLOT(*pte);
    if (swap_read(p->swap_ip, slot, mem, PGSIZE, 0) < 0)
      panic("vm_fault: swap read");
    slot_free(p, slot);
    printk("[pid %d] SWAPIN va=0x%lx slot=%d\n", p->pid, va0, slot);
    perm = *pte & (PTE_R | PTE_X | PTE_U | PTE_SWW);
    backed = 0; // the only copy is now in memory
  } else if (cause == C_EXEC) {
    if (load_exec_page(p, va0, mem) < 0) {
      kfree((void *)mem);
      setkilled(p);
      return 0;
    }
    printk("[pid %d] LOADEXEC va=0x%lx\n", p->pid, va0);
    perm = PTE_R | PTE_U | (s->perm & PTE_X) |
           ((s->perm & PTE_W) ? PTE_SWW : 0);
    backed = 1;
  } else {
    memset((void *)mem, 0, PGSIZE);
    printk("[pid %d] ALLOC va=0x%lx\n", p->pid, va0);
    perm = PTE_R | PTE_U | PTE_SWW;
    backed = 1;
  }

  // A write fault writes the page right away, so map it dirty now.
  int dirty = 0;
  if (access == ACC_WRITE && (perm & PTE_SWW)) {
    perm = (perm & ~PTE_SWW) | PTE_W | PTE_D;
    dirty = 1;
  }
  *pte = PA2PTE(mem) | perm | PTE_V | PTE_A;
  sfence_vma();

  uint seq = p->next_seq;
  p->next_seq = (p->next_seq + 1) & SEQMASK;
  frame_add(p, mem, va0, seq, dirty, backed);
  printk("[pid %d] RESIDENT va=0x%lx seq=%d\n", p->pid, va0, (int)seq);
  return mem;
}

// Fault in [addr, addr+n) of the current process ahead of a copyin()
// (write=0) or copyout() (write=1) that will run with a spinlock held
// (pipes, console, wait), where the fault could not sleep.
void
vm_prefault(uint64 addr, uint64 n, int write)
{
  struct proc *p = myproc();
  if (n == 0 || addr >= p->sz || addr + n < addr)
    return;
  uint64 end = addr + n;
  if (end > p->sz)
    end = p->sz;
  for (uint64 va = PGROUNDDOWN(addr); va < end; va += PGSIZE) {
    pte_t *pte = walk(p->pagetable, va, 0);
    if (pte && (*pte & PTE_V) && (!write || (*pte & PTE_W)))
      continue;
    if (vm_fault(p, va, write ? ACC_WRITE : ACC_READ, 0) == 0)
      return;
  }
}

// ---------------------------------------------------------------------
// Process life cycle.

// exec() committed to a new image: record its layout, start a fresh swap
// file and FIFO, and log INIT-LAZYMAP. ip is a referenced, unlocked inode.
void
vm_exec(struct proc *p, struct inode *ip, struct vmseg *seg, int nseg,
        uint64 stack_bottom, uint64 stack_top)
{
  begin_op();
  if (p->exec_ip)
    iput(p->exec_ip);
  end_op();
  p->exec_ip = ip;
  p->nseg = nseg;
  p->text_start = p->text_end = 0;
  p->data_start = p->data_end = 0;
  int havetext = 0, havedata = 0;
  for (int i = 0; i < nseg; i++) {
    p->seg[i] = seg[i];
    uint64 lo = seg[i].vaddr, hi = PGROUNDUP(seg[i].vaddr + seg[i].memsz);
    if ((seg[i].perm & PTE_X) && !havetext) {
      p->text_start = lo;
      p->text_end = hi;
      havetext = 1;
    } else if (!(seg[i].perm & PTE_X) && !havedata) {
      p->data_start = lo;
      p->data_end = hi;
      havedata = 1;
    }
  }
  if (!havedata)
    p->data_start = p->data_end = p->text_end;
  p->stack_bottom = stack_bottom;
  p->stack_top = stack_top;
  p->next_seq = 0;

  // The old image's swapped pages are gone with its page table.
  memset(p->swap_map, 0, sizeof(p->swap_map));
  p->swap_used = 0;
  if (p->swap_ip) {
    begin_op();
    ilock(p->swap_ip);
    itrunc(p->swap_ip);
    iunlock(p->swap_ip);
    end_op();
  } else {
    p->swap_ip = swap_create(p->pid);
  }

  printk("[pid %d] INIT-LAZYMAP text=[0x%lx,0x%lx) data=[0x%lx,0x%lx) "
         "heap_start=0x%lx stack_top=0x%lx\n",
         p->pid, p->text_start, p->text_end, p->data_start, p->data_end,
         stack_top, stack_top);
}

// fork(): give child np a copy of p's address space. np->pagetable is
// empty. Resident pages are copied into new frames (or, if memory is
// full, straight into np's swap file); swapped pages are copied from p's
// swap file into np's. np gets its own swap file. Returns 0 or -1.
int
vm_fork(struct proc *p, struct proc *np)
{
  char buf[512];

  np->exec_ip = p->exec_ip ? idup(p->exec_ip) : 0;
  np->nseg = p->nseg;
  for (int i = 0; i < p->nseg; i++)
    np->seg[i] = p->seg[i];
  np->text_start = p->text_start;
  np->text_end = p->text_end;
  np->data_start = p->data_start;
  np->data_end = p->data_end;
  np->stack_bottom = p->stack_bottom;
  np->stack_top = p->stack_top;
  np->next_seq = p->next_seq; // child keeps the parent's FIFO order
  memset(np->swap_map, 0, sizeof(np->swap_map));
  np->swap_used = 0;
  if ((np->swap_ip = swap_create(np->pid)) == 0)
    return -1;

  for (uint64 va = 0; va < p->sz; va += PGSIZE) {
    pte_t *pte = walk(p->pagetable, va, 0);
    if (pte == 0 || (*pte & (PTE_V | PTE_SWAP)) == 0)
      continue; // never touched
    pte_t *npte = walk(np->pagetable, va, 1);
    if (npte == 0)
      return -1;
    if (*pte & PTE_V) {
      uint64 pa = PTE2PA(*pte);
      uint64 flags = PTE_FLAGS(*pte);
      acquire(&framelock);
      struct frame f = *pa2frame(pa);
      release(&framelock);
      char *mem = kalloc();
      if (mem) {
        memmove(mem, (char *)pa, PGSIZE);
        *npte = PA2PTE(mem) | flags;
        frame_add(np, (uint64)mem, va, f.seq, f.dirty, f.backed);
      } else {
        int slot = slot_alloc(np);
        if (slot < 0 || swap_write(np, slot, pa) < 0)
          return -1;
        uint64 sflags = flags & (PTE_R | PTE_X | PTE_U | PTE_SWW);
        if (flags & PTE_W)
          sflags |= PTE_SWW;
        if (f.dirty)
          sflags |= PTE_D;
        *npte = SLOT2PTE(slot) | sflags | PTE_SWAP;
      }
    } else {
      int pslot = PTE2SLOT(*pte);
      int slot = slot_alloc(np);
      if (slot < 0)
        return -1;
      for (uint off = 0; off < PGSIZE; off += sizeof(buf)) {
        if (swap_read(p->swap_ip, pslot, (uint64)buf, sizeof(buf), off) < 0)
          return -1;
        begin_op();
        ilock(np->swap_ip);
        int n = writei(np->swap_ip, 0, (uint64)buf, slot * PGSIZE + off,
                       sizeof(buf));
        iunlock(np->swap_ip);
        end_op();
        if (n != sizeof(buf))
          return -1;
      }
      *npte = SLOT2PTE(slot) | PTE_FLAGS(*pte);
    }
  }
  return 0;
}

// Release p's swap file and executable. log=1 on a real exit (prints
// SWAPCLEANUP), 0 when cleaning up after a failed fork.
void
vm_free(struct proc *p, int log)
{
  if (log && p->swap_ip)
    printk("[pid %d] SWAPCLEANUP freed_slots=%d\n", p->pid, p->swap_used);
  swap_delete(p);
  memset(p->swap_map, 0, sizeof(p->swap_map));
  p->swap_used = 0;
  if (p->exec_ip) {
    begin_op();
    iput(p->exec_ip);
    end_op();
    p->exec_ip = 0;
  }
}

// sbrk(-n): pages in [newsz, oldsz) go away; free their swap slots.
// (Resident ones are freed by uvmdealloc().)
void
vm_shrink(struct proc *p, uint64 oldsz, uint64 newsz)
{
  for (uint64 va = PGROUNDUP(newsz); va < PGROUNDUP(oldsz); va += PGSIZE) {
    pte_t *pte = walk(p->pagetable, va, 0);
    if (pte && !(*pte & PTE_V) && (*pte & PTE_SWAP)) {
      slot_free(p, PTE2SLOT(*pte));
      *pte = 0;
    }
  }
}

// ---------------------------------------------------------------------
// memstat()

static int
cpout(uint64 dst, void *src, uint64 n)
{
  struct proc *p = myproc();
  return copyout(p->pagetable, p->sz, dst, (char *)src, n);
}

int
vm_memstat(uint64 addr)
{
  struct proc *p = myproc();
  int total = 0, nres = 0, nswap = 0, i = 0;

  // Bring the result buffer in first, so copying it out below does not
  // change the residency we are reporting.
  vm_prefault(addr, sizeof(struct proc_mem_stat), 1);

  for (uint64 va = 0; va < p->sz; va += PGSIZE, total++) {
    pte_t *pte = walk(p->pagetable, va, 0);
    struct page_stat ps;
    ps.va = (uint)va;
    ps.state = UNMAPPED;
    ps.is_dirty = 0;
    ps.seq = -1;
    ps.swap_slot = -1;
    if (pte && (*pte & PTE_V) && (*pte & PTE_U)) {
      nres++;
      ps.state = RESIDENT;
      acquire(&framelock);
      struct frame *f = pa2frame(PTE2PA(*pte));
      ps.seq = (int)f->seq;
      ps.is_dirty = f->dirty;
      release(&framelock);
    } else if (pte && !(*pte & PTE_V) && (*pte & PTE_SWAP)) {
      nswap++;
      ps.state = SWAPPED;
      ps.swap_slot = PTE2SLOT(*pte);
      ps.is_dirty = (*pte & PTE_D) ? 1 : 0;
    }
    if (i < MAX_PAGES_INFO) {
      uint64 dst = addr + (uint64)&((struct proc_mem_stat *)0)->pages[i];
      if (cpout(dst, &ps, sizeof(ps)) < 0)
        return -1;
      i++;
    }
  }

  struct proc_mem_stat *z = 0;
  int pid = p->pid, seq = (int)p->next_seq;
  if (cpout(addr + (uint64)&z->pid, &pid, sizeof(int)) < 0 ||
      cpout(addr + (uint64)&z->num_pages_total, &total, sizeof(int)) < 0 ||
      cpout(addr + (uint64)&z->num_resident_pages, &nres, sizeof(int)) < 0 ||
      cpout(addr + (uint64)&z->num_swapped_pages, &nswap, sizeof(int)) < 0 ||
      cpout(addr + (uint64)&z->next_fifo_seq, &seq, sizeof(int)) < 0)
    return -1;

  // Unused entries of pages[] are zeroed.
  struct page_stat zero;
  memset(&zero, 0, sizeof(zero));
  for (; i < MAX_PAGES_INFO; i++) {
    uint64 dst = addr + (uint64)&z->pages[i];
    if (cpout(dst, &zero, sizeof(zero)) < 0)
      return -1;
  }
  return 0;
}
// ############## LLM Generated Code Ends ################
