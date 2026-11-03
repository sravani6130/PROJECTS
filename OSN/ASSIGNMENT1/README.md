# Part 1: File Management

A lightweight, interactive, file-based shell written in C that demonstrates Unix process management, file descriptor redirection, and standard I/O stream synchronization.

## Task Overview

When executed, the program acts as a tiny file-based shell:
1. **Startup & Setup:**
   - Retrieves its current Process ID (`pid`).
   - Creates a dedicated working directory named `folder_<pid>`.
   - Inside that directory, creates two empty files:
     - `content.txt`: stores all user text inputs.
     - `logs.txt`: stores an audit log of user interactions and commands.
2. **Interactive Command Loop:**
   - Enters an interactive loop prompting the user with `Enter command:`.
   - Evaluates commands, writes data or logs, and displays results to the terminal.

## Supported Commands

All commands are case-sensitive:

| Command | Action | Logged to `logs.txt`? |
| :--- | :--- | :--- |
| **`INPUT`** | Prompts with `INPUT -> ` and accepts a line of text. Appends that line to `content.txt`. | **Yes** (`INPUT`) |
| **`PRINT`** | Displays the entire contents of `content.txt` on the terminal. | **Yes** (`PRINT`) |
| **`FIRST <n>`** | Displays the first $n$ lines of `content.txt`. | **Yes** (`FIRST <n>`) |
| **`LAST <n>`** | Displays the last $n$ lines of `content.txt`. | **Yes** (`LAST <n>`) |
| **`LOG <n>`** | Displays the $n$ latest entries from `logs.txt`. | **No** |
| **`STOP`** | Logs `STOP` and cleanly terminates the program. | **Yes** (`STOP`) |
| *Unrecognized* | Any unknown or malformed input prints `Unknown command..`. | **No** |

## Restrictions & The Technical Challenge

The assignment enforces strict constraints:
- **Forbidden Functions:** `fread`, `fwrite`, `read`, `write`, `fprintf`, `fscanf`, `fgets`, `fputs`.
- **Allowed I/O Functions:** **Only `scanf` and `printf`**.

### The Solution: File Descriptor Redirection
Because `printf` is hardwired to File Descriptor 1 (`stdout`) and `scanf` is hardwired to File Descriptor 0 (`stdin`), we cannot pass file pointers to them directly. 

Instead, we manipulate the process's **File Descriptor Table**:
- **To write to a file using `printf`:**
  1. Save original standard output using `dup(STDOUT_FILENO)`.
  2. Open the destination file (`content.txt` or `logs.txt`) with `open()`.
  3. Redirect FD 1 to point to the file descriptor using `dup2()`.
  4. Emit the text using `printf()`.
  5. Restore standard output back to the terminal using `dup2()`.
- **To read from a file using `scanf`:**
  1. Save original standard input using `dup(STDIN_FILENO)`.
  2. Open the file in read-only mode with `open()`.
  3. Redirect FD 0 to point to the file using `dup2()`.
  4. Fetch characters/lines using `scanf("%c", &ch)` until `EOF`.
  5. Restore standard input back to the keyboard using `dup2()`.
  6. Call `clearerr(stdin)` to reset the stream EOF indicator.

### Stream Buffering
Standard C I/O buffers 4 KB of data in user space. If standard descriptors are swapped using `dup2`, `scanf` would read stale data lingering in libc's buffer. To prevent this, buffering is disabled on startup using:
```c
setvbuf(stdin, NULL, _IONBF, 0);
setvbuf(stdout, NULL, _IONBF, 0);
```

---

# Part 2: Process Creation and Management

Part 2 explores process creation via `fork()`, process replacement via `execvp()`, parent-child memory isolation, and process lifecycle dynamics (orphan processes and `init`/`systemd` adoption).

## Tasks Overview

### Task 1: Variable Isolation (Address Space Separation)
- In the parent process, an integer variable is initialized to `x = 25`.
- The parent forks a child process:
  - **Child:** Increments `x` by 10 (`x = 35`) and prints its value with its PID.
  - **Parent:** Decrements `x` by 5 (`x = 20`) and prints its value with its PID.
- **Concept Demonstrated:** When `fork()` is called, the child receives a duplicate of the parent's virtual address space (via Copy-On-Write). Modifications to variables in the child do **not** affect variables in the parent, proving memory space isolation between processes.

### Task 2: Executing an External Program (`writer.c`)
- In `part2.c`, the parent forks a child.
- The child uses `execvp("./writer", args)` to replace its process image with the standalone program `./writer`.
- The `writer` program:
  1. Queries its parent's PID using `getppid()`.
  2. Opens (or creates) `newfile.txt`.
  3. Writes the parent PID to `newfile.txt` and exits cleanly.
- The parent process waits for the child to finish via `waitpid()`, then opens and verifies that `newfile.txt` contains the parent's PID.

### Task 3: Orphan Process Demonstration
- The parent forks a child process.
- **Parent:** Prints its PID and immediately terminates using `exit(0)` *before* the child finishes.
- **Child:** Executes `sleep(2)` to ensure the parent has already died, and then prints its own PID and its parent PID (`getppid()`).

---

## 🔍 Comparison & Analysis: Task 2 vs. Task 3

### 1. Comparison of Results

| Metric | Task 2 (`newfile.txt`) | Task 3 (Printed by Child) |
| :--- | :--- | :--- |
| **Parent PID Recorded** | The original PID of `part2` (e.g., `26980`) | `2343` (Adoptive `systemd` subreaper / `init` PID 1) |
| **State of Parent** | Alive and waiting via `waitpid()` | Terminated and reaped |
| **Child Status** | Normal active child process | **Orphan Process** |

### 2. Why Do They Differ?
- In **Task 2**, the parent process is alive throughout the child's execution. When `./writer` calls `getppid()`, its biological parent (`part2`) exists and is actively waiting for it. Hence, `getppid()` returns the actual PID of `part2`.
- In **Task 3**, the parent process explicitly terminates while the child is sleeping for 2 seconds. In Unix-like operating systems, a process cannot exist without a parent. When a parent dies before its child, the child becomes an **orphan process**.
- The Linux kernel automatically **re-parents** the orphaned child to the ancestor process designated as the subreaper, typically `init` (PID 1) or `systemd`. Therefore, when the child wakes up after 2 seconds and calls `getppid()`, its parent is no longer `part2`; it has been adopted by PID 1 (`init`/`systemd`).

### 3. What Is the Role of the `init` / `systemd` Process?
1. **Adopting Orphaned Processes:**  
   When a parent process dies, the kernel attaches all of its active children to PID 1 (`init`/`systemd`), ensuring the process tree remains a connected, hierarchical graph rooted at PID 1.
2. **Reaping Zombie Processes (Preventing Resource Leaks):**  
   When any process terminates, its metadata (exit status, PID, resource usage) remains in the kernel's Process Table in a `<defunct>` (zombie) state until its parent calls `wait()` or `waitpid()`. If an orphan had no parent, no one would ever call `wait()`, and the process table would permanently fill with zombies, eventually exhausting available PIDs. `init`/`systemd` runs an infinite loop waiting for adopted children, promptly reaping them upon termination and freeing system resources.
3. **System Initialization and Service Supervision:**  
   `init`/`systemd` is the very first user-space process started by the Linux kernel at boot time. It bootstraps user-space, starts system daemons, manages user sessions, and supervises system services.

---

## System Calls Used in Part 1 & Part 2

| System Call | Header | Used In | Purpose |
| :--- | :--- | :--- | :--- |
| **`fork()`** | `<unistd.h>` | Part 2 | Creates a new child process duplicating the calling process. |
| **`execvp()`** | `<unistd.h>` | Part 2 | Replaces the current process image with a new executable (`./writer`). |
| **`waitpid()`** | `<sys/wait.h>` | Part 2 | Suspends parent execution until child process state changes (prevents zombies). |
| **`getpid()`** | `<unistd.h>` | Part 1 & 2 | Queries current process PID. |
| **`getppid()`** | `<unistd.h>` | Part 2 | Queries parent process PID. |
| **`sleep()`** | `<unistd.h>` | Part 2 | Suspends process execution for specified duration. |
| **`mkdir()`** | `<sys/stat.h>` | Part 1 | Creates directories (`folder_<pid>`). |
| **`open()`** | `<fcntl.h>` | Part 1 & 2 | Opens or creates files and returns integer file descriptors. |
| **`close()`** | `<unistd.h>` | Part 1 & 2 | Closes open file descriptors to prevent resource leaks. |
| **`dup()`** | `<unistd.h>` | Part 1 | Duplicates file descriptors to back up `stdin`/`stdout`. |
| **`dup2()`** | `<unistd.h>` | Part 1 | Redirects `stdin` (0) or `stdout` (1) for file I/O with `scanf`/`printf`. |

---

## References & Conceptual Learning

To understand the core concepts of file descriptors, file descriptor tables, standard streams, and how redirection works in the Linux kernel, the following reference was used:
- **[Linux File Descriptors by Tharindu Imalka](https://medium.com/@tharinduimalka915/linux-file-descriptors-ec945fd36893)**

---

## File Structure

```text
ASSIGNMENT1/
├── Makefile       # Root Makefile that builds both Part1 and Part2
├── README.md      # Comprehensive assignment documentation
├── Part1/         # Part 1: File Management
│   ├── Makefile   # Build automation for Part 1
│   ├── part1.c    # File management shell implementation
│   └── part1      # Compiled executable for Part 1
└── Part2/         # Part 2: Process Creation and Management
    ├── Makefile   # Build automation for Part 2
    ├── part2.c    # Process management implementation (Tasks 1, 2, 3)
    ├── part2      # Compiled executable for Part 2
    ├── writer.c   # External writer program for Task 2
    ├── writer     # Compiled executable for writer
    └── newfile.txt# Output file generated by writer containing parent PID
```

---

## Compilation and Execution

### Compiling via GCC Directly:
```bash
# Part 1
gcc -Wall -Wextra -O2 -o part1 part1.c

# Part 2
gcc -Wall -Wextra -O2 -o writer writer.c
gcc -Wall -Wextra -O2 -o part2 part2.c
```

### Compiling via Makefile:
```bash
cd ~/Desktop/OSN/ASSIGNMENT1
make        # Builds both Part1 and Part2
make clean  # Cleans binaries and temporary files across both parts
```

### Running Part 1:
```bash
cd ~/Desktop/OSN/ASSIGNMENT1/Part1
./part1
```

### Running Part 2:
```bash
cd ~/Desktop/OSN/ASSIGNMENT1/Part2

# Run all three tasks sequentially:
./part2

# Or run individual tasks:
./part2 1   # Run Task 1 only
./part2 2   # Run Task 2 only
./part2 3   # Run Task 3 only
```

---

## Example Outputs

### Part 1: Interactive Shell Session
```text
Enter command:INPUT
INPUT -> Hello world!
Enter command:INPUT
INPUT -> This is a test.
Enter command:PRINT
Hello world!
This is a test.
Enter command:FIRST 1
Hello world!
Enter command:LAST 1
This is a test.
Enter command:LOG 2
FIRST 1
LAST 1
Enter command:STOP
```

### Part 2: Process Creation, Execution, and Orphan Demonstration
```text
sravani@sravani-Latitude-3440:~/Desktop/OSN/ASSIGNMENT1/Part2$ gcc -Wall -Wextra -O2 -o writer writer.c
sravani@sravani-Latitude-3440:~/Desktop/OSN/ASSIGNMENT1/Part2$ gcc -Wall -Wextra -O2 -o part2 part2.c
sravani@sravani-Latitude-3440:~/Desktop/OSN/ASSIGNMENT1/Part2$ ./part2
========================================
         TASK 1: VARIABLE ISOLATION     
========================================
[Task 1] Initial x in Parent (PID: 26980) = 25
[Task 1] Parent (PID: 26980): x decremented by 5  -> x = 20
[Task 1] Child  (PID: 26981): x incremented by 10 -> x = 35

========================================
     TASK 2: EXEC EXTERNAL PROGRAM      
========================================
[writer] Successfully wrote Parent PID (26980) to newfile.txt
[Task 2] Parent (PID: 26980) verified newfile.txt contains Parent PID: 26980

========================================
       TASK 3: ORPHAN PROCESS DEMO      
========================================
[Task 3] Parent (PID: 26980): Terminating now before child finishes...
[Task 3] Child  (PID: 26983): Created with initial Parent PID = 26980. Sleeping 2 seconds...
sravani@sravani-Latitude-3440:~/Desktop/OSN/ASSIGNMENT1/Part2$ 
[Task 3] Child  (PID: 26983): Woke up!
[Task 3] Child  (PID: 26983): My PID = 26983, Parent PID = 2343 (Adopted by init/systemd)
```

#### Output Analysis & Key Observations:
1. **Task 1 (Variable Isolation):**
   - Parent PID is `26980` and Child PID is `26981`.
   - In the parent, $x$ became $25 - 5 = 20$. In the child, $x$ became $25 + 10 = 35$.
   - Demonstrates that `fork()` provides memory isolation via Copy-On-Write (COW). Changes in the child do not affect the parent.
2. **Task 2 (Exec External Program):**
   - The child executed `./writer` using `execvp()`.
   - The parent PID queried by `writer` via `getppid()` was `26980` (the active parent).
   - Confirms that `execvp()` replaces the process image in memory while preserving the process hierarchy (PID and PPID).
3. **Task 3 (Orphan Process & Re-parenting):**
   - The parent (`26980`) called `exit(0)` while the child (`26983`) was sleeping.
   - Because the parent exited, the bash shell prompt returned immediately.
   - After 2 seconds, the child woke up in the background and printed its parent PID.
   - The parent PID changed from `26980` to **`2343`** because the Linux kernel re-parented the orphaned child to the user session subreaper (`systemd --user`, PID `2343`).

