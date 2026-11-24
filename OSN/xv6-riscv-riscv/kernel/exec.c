#include "types.h"
#include "param.h"
#include "memlayout.h"
#include "riscv.h"
#include "spinlock.h"
#include "proc.h"
#include "defs.h"
#include "elf.h"


// map ELF permissions to PTE permission bits.
int
flags2perm(int flags)
{
  int perm = 0;
  if (flags & 0x1)
    perm = PTE_X;
  if (flags & 0x2)
    perm |= PTE_W;
  return perm;
}

//
// the implementation of the exec() system call
//
// ############## LLM Generated Code Begins ##############
int
kexec(char *path, char **argv)
{
  char *s, *last;
  int i, off, nseg = 0;
  uint64 argc, sz = 0, sp, ustack[MAXARG], stackbase;
  struct elfhdr elf;
  struct inode *ip;
  struct proghdr ph;
  struct vmseg seg[MAXVMSEG];
  pagetable_t pagetable = 0, oldpagetable;
  struct proc *p = myproc();

  begin_op();

  // Open the executable file.
  if ((ip = namei(path)) == 0) {
    end_op();
    return -1;
  }
  ilock(ip);

  // Read the ELF header.
  if (readi(ip, 0, (uint64)&elf, 0, sizeof(elf)) != sizeof(elf))
    goto bad;

  // Is this really an ELF file?
  if (elf.magic != ELF_MAGIC)
    goto bad;

  if ((pagetable = proc_pagetable(p)) == 0)
    goto bad;

  // Demand paging: only record the loadable segments. Their pages are
  // read from the executable on the first page fault (LOADEXEC).
  for (i = 0, off = elf.phoff; i < elf.phnum; i++, off += sizeof(ph)) {
    if (readi(ip, 0, (uint64)&ph, off, sizeof(ph)) != sizeof(ph))
      goto bad;
    if (ph.type != ELF_PROG_LOAD)
      continue;
    if (ph.memsz < ph.filesz)
      goto bad;
    if (ph.vaddr + ph.memsz < ph.vaddr)
      goto bad;
    if (ph.vaddr % PGSIZE != 0)
      goto bad;
    if (ph.vaddr + ph.memsz > TRAPFRAME)
      goto bad;
    if (nseg == MAXVMSEG)
      goto bad;
    seg[nseg].vaddr = ph.vaddr;
    seg[nseg].memsz = ph.memsz;
    seg[nseg].filesz = ph.filesz;
    seg[nseg].off = ph.off;
    seg[nseg].perm = flags2perm(ph.flags);
    nseg++;
    if (ph.vaddr + ph.memsz > sz)
      sz = ph.vaddr + ph.memsz;
  }
  // Keep a reference to the executable for loading pages later.
  iunlock(ip);
  end_op();

  // Layout: [text][data] [guard page] [stack] [heap ...]
  // Nothing is mapped; the guard page is simply never valid.
  sz = PGROUNDUP(sz);
  stackbase = sz + PGSIZE;
  sz = sz + (USERSTACK + 1) * PGSIZE;
  sp = sz;

  // Work out where the argument strings go before committing, so that
  // the only thing that can still fail afterwards is running out of memory.
  for (argc = 0; argv[argc]; argc++) {
    if (argc >= MAXARG)
      goto bad2;
    sp -= strlen(argv[argc]) + 1;
    sp -= sp % 16; // riscv sp must be 16-byte aligned
    if (sp < stackbase)
      goto bad2;
    ustack[argc] = sp;
  }
  ustack[argc] = 0;
  sp -= (argc + 1) * sizeof(uint64);
  sp -= sp % 16;
  if (sp < stackbase)
    goto bad2;

  // Save program name for debugging.
  for (last = s = path; *s; s++)
    if (*s == '/')
      last = s + 1;
  safestrcpy(p->name, last, sizeof(p->name));

  // Commit to the user image.
  uint64 oldsz = p->sz;
  oldpagetable = p->pagetable;
  p->pagetable = pagetable;
  p->sz = sz;
  proc_freepagetable(oldpagetable, oldsz);
  vm_exec(p, ip, seg, nseg, stackbase, sz); // logs INIT-LAZYMAP
  p->trapframe->sp = sp; // for the stack-fault check

  // Copy the argument strings and the argv[] array onto the stack.
  // The first copy faults the stack page in (PAGEFAULT ... cause=stack).
  for (i = 0; i < argc; i++)
    if (copyout(pagetable, sz, ustack[i], argv[i], strlen(argv[i]) + 1) < 0)
      goto killed;
  if (copyout(pagetable, sz, sp, (char *)ustack, (argc + 1) * sizeof(uint64)) <
      0)
    goto killed;

  // a0 and a1 contain arguments to user main(argc, argv)
  // argc is returned via the system call return
  // value, which goes in a0.
  p->trapframe->a1 = sp;
  p->trapframe->epc = elf.entry; // initial program counter = ulib.c:start()
  p->trapframe->sp = sp;         // initial stack pointer

  return argc; // this ends up in a0, the first argument to main(argc, argv)

killed:
  // Past the point of no return (out of memory): the process cannot go on.
  setkilled(p);
  return -1;

bad2:
  proc_freepagetable(pagetable, 0);
  begin_op();
  iput(ip);
  end_op();
  return -1;

bad:
  if (pagetable)
    proc_freepagetable(pagetable, 0);
  if (ip) {
    iunlockput(ip);
    end_op();
  }
  return -1;
}
// ############## LLM Generated Code Ends ################
