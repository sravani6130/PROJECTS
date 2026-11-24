// readcount: test for the getreadcount() system call (Part A.2).
//
// Usage: readcount [file]      (default file: README)
//
// 1. Prints the current system-wide read byte count.
// 2. Reads 100 bytes from the file.
// 3. Prints the count again and checks it increased by the bytes read.

#include "kernel/types.h"
#include "kernel/fcntl.h"
#include "user/user.h"

#define NBYTES 100

int
main(int argc, char *argv[])
{
  char *file = (argc > 1) ? argv[1] : "README";
  char buf[NBYTES];

  uint before = getreadcount();
  printf("Initial read count: %u\n", before);

  int fd = open(file, O_RDONLY);
  if (fd < 0) {
    fprintf(2, "readcount: cannot open %s\n", file);
    exit(1);
  }

  // read() may return fewer bytes than asked, so loop until 100 bytes or EOF.
  int total = 0;
  while (total < NBYTES) {
    int n = read(fd, buf + total, NBYTES - total);
    if (n < 0) {
      fprintf(2, "readcount: read error on %s\n", file);
      close(fd);
      exit(1);
    }
    if (n == 0)
      break; // EOF: file is shorter than 100 bytes
    total += n;
  }
  close(fd);
  printf("Read %d bytes from %s\n", total, file);

  uint after = getreadcount();
  printf("Read count after read: %u\n", after);

  // Unsigned subtraction gives the right answer even if the counter wrapped.
  uint diff = after - before;
  printf("Increase: %u bytes\n", diff);

  if (diff == (uint)total)
    printf("OK: read count increased by %d as expected\n", total);
  else
    printf("MISMATCH: expected increase of %d, got %u\n", total, diff);

  exit(0);
}
