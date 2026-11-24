// ############## LLM Generated Code Begins ##############
// lazytest: demand paging basics and memstat().
//   - sbrk() maps nothing; the first access zero-fills a page (ALLOC)
//   - reads leave a page clean, writes make it dirty
//   - invalid accesses kill the process (run in children)
#include "kernel/types.h"
#include "kernel/memstat.h"
#include "user/user.h"

#define PG 4096

static struct proc_mem_stat st;
static char *statename[] = {"UNMAPPED", "RESIDENT", "SWAPPED"};

static void
show(char *when)
{
  if (memstat(&st) < 0) {
    printf("lazytest: memstat failed\n");
    exit(1);
  }
  printf("-- %s: pid=%d total=%d resident=%d swapped=%d next_seq=%d\n", when,
         st.pid, st.num_pages_total, st.num_resident_pages,
         st.num_swapped_pages, st.next_fifo_seq);
  int n = st.num_pages_total < MAX_PAGES_INFO ? st.num_pages_total
                                              : MAX_PAGES_INFO;
  for (int i = 0; i < n; i++) {
    struct page_stat *ps = &st.pages[i];
    if (ps->state == UNMAPPED)
      continue;
    printf("   va=0x%x %s dirty=%d seq=%d slot=%d\n", ps->va,
           statename[ps->state], ps->is_dirty, ps->seq, ps->swap_slot);
  }
}

// Find a page's entry in the last memstat() result.
static struct page_stat *
page(char *va)
{
  for (int i = 0; i < MAX_PAGES_INFO; i++)
    if (st.pages[i].va == (uint)(uint64)va)
      return &st.pages[i];
  return 0;
}

static int fails = 0;
static void
check(int ok, char *what)
{
  printf("%s: %s\n", ok ? "PASS" : "FAIL", what);
  if (!ok)
    fails++;
}

// Run f in a child; it must be killed (exit status -1).
static void
mustdie(void (*f)(void), char *what)
{
  int pid = fork();
  if (pid == 0) {
    f();
    exit(0); // not reached if the kernel kills us
  }
  int status = 0;
  wait(&status);
  check(status == -1, what);
}

static void
read_past_sz(void)
{
  volatile char *bad = sbrk(0) + 8 * PG;
  printf("%d\n", *bad);
}

static void
write_text(void)
{
  *(volatile char *)(uint64)show = 0;
}

static void
exec_heap(void)
{
  char *h = sbrk(PG);
  h[0] = 0;
  ((void (*)(void))h)();
}

int
main(void)
{
  show("start");

  char *p = sbrk(3 * PG);
  show("after sbrk(3 pages)");
  check(memstat(&st) == 0 && page(p)->state == UNMAPPED,
        "sbrk does not allocate");

  p[0] = 'x'; // write fault -> ALLOC, dirty
  volatile char c = p[PG]; // read fault -> ALLOC, clean
  (void)c;
  memstat(&st);
  check(page(p)->state == RESIDENT && page(p)->is_dirty == 1,
        "write fault: resident and dirty");
  check(page(p + PG)->state == RESIDENT && page(p + PG)->is_dirty == 0 &&
          p[PG] == 0,
        "read fault: resident, clean, zero-filled");
  check(page(p + 2 * PG)->state == UNMAPPED, "untouched page stays unmapped");
  check(page(p + PG)->seq > page(p)->seq, "FIFO seq increases");

  p[PG] = 'y'; // first write to a clean page
  memstat(&st);
  check(page(p + PG)->is_dirty == 1, "first write marks page dirty");
  show("after touching 2 of 3 heap pages");

  mustdie(read_past_sz, "read beyond sz kills the process");
  mustdie(write_text, "write to text kills the process");
  mustdie(exec_heap, "executing the heap kills the process");

  if (fails == 0)
    printf("lazytest: OK\n");
  else
    printf("lazytest: %d FAILED\n", fails);
  exit(fails != 0);
}
// ############## LLM Generated Code Ends ################
