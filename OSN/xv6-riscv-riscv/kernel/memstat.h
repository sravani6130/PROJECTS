// ############## LLM Generated Code Begins ##############
// memstat() system call: a snapshot of the calling process's pages.
// Shared by the kernel and user programs.

#define MAX_PAGES_INFO 128 // max pages reported (lowest addresses first)

// Page states
#define UNMAPPED 0
#define RESIDENT 1
#define SWAPPED  2

struct page_stat {
  uint va;       // page-aligned virtual address
  int state;     // UNMAPPED, RESIDENT or SWAPPED
  int is_dirty;  // 1 if written since it was brought into memory
  int seq;       // FIFO sequence number (resident pages), else -1
  int swap_slot; // swap slot (swapped pages), else -1
};

struct proc_mem_stat {
  int pid;
  int num_pages_total;    // pages in [0, sz): resident + swapped + unmapped
  int num_resident_pages;
  int num_swapped_pages;
  int next_fifo_seq;      // seq the next resident page will get
  struct page_stat pages[MAX_PAGES_INFO];
};
// ############## LLM Generated Code Ends ################
