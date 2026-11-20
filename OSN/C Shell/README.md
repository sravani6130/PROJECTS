# C Shell

A small Unix shell written in C for CS3301 (Operating Systems and Networks), Mini Project 1.

If you have used the Linux terminal, you have used a shell: it is the program that shows a
prompt, reads what you type, and runs it. This project builds one from scratch. It can run
programs like `ls` and `cat`, connect them with pipes, send output to files, run jobs in the
background, and pause or resume them with the keyboard.

## Contents
- [Quick start](#quick-start)
- [A short tour](#a-short-tour)
- [Key ideas in one page](#key-ideas-in-one-page)
- [How a command is processed](#how-a-command-is-processed)
- [Command reference](#command-reference)
- [Source layout](#source-layout)
- [Where to start reading the code](#where-to-start-reading-the-code)
- [Design notes](#design-notes)
- [Assumptions](#assumptions)

## Quick start

You need Linux with `gcc` and `make` installed. On Ubuntu: `sudo apt install build-essential`.

```bash
cd shell
make all          # compiles everything into ./shell.out
./shell.out       # starts the shell
```

Type commands at the prompt. To leave the shell, press **Ctrl-D**.

`make clean` removes the compiled files if you want to rebuild from scratch.

The code compiles with the flags the assignment requires, with no warnings:

```
gcc -std=c99 -D_POSIX_C_SOURCE=200809L -D_XOPEN_SOURCE=700 -Wall -Wextra -Werror -Wno-unused-parameter -fno-asm
```

Only POSIX headers and functions are used, and the Part A and Part B built-ins do not use any `exec*` call.

## A short tour

Below is a sample session. Lines starting with `<` are the prompt; everything after `>` is what
was typed. The other lines are the shell's output.

```
<sravani@laptop:~> reveal
Makefile README.md include shell.out src
<sravani@laptop:~> hop src
<sravani@laptop:~/src> hop ..
<sravani@laptop:~> echo hello > note.txt
<sravani@laptop:~> cat note.txt
hello
<sravani@laptop:~> reveal -l | wc -l
5
<sravani@laptop:~> sleep 3 &
[1] 4242
<sravani@laptop:~> activities
[4242] : sleep - Running
<sravani@laptop:~> echo done
sleep with pid 4242 exited normally
done
<sravani@laptop:~> log
reveal
hop src
hop ..
echo hello > note.txt
...
<sravani@laptop:~> ls |
Invalid Syntax!
```

What happened, line by line:
1. `reveal` listed the current directory.
2. `hop src` moved into `src`; the prompt changed to `~/src`. `hop ..` moved back.
3. `echo hello > note.txt` wrote `hello` into a file instead of the screen.
4. `reveal -l | wc -l` sent the list of files into `wc`, which counted the lines.
5. `sleep 3 &` ran in the background, so the prompt came back immediately.
6. `activities` showed the background job. When it finished, the shell reported it.
7. `log` showed the command history.
8. `ls |` is not a complete command, so the shell refused it.

## Key ideas in one page

You only need these terms to understand the rest of this README and the code.

| Term | Plain meaning |
|---|---|
| **Process** | A running program. Every process has a number called its **pid**. |
| **Parent / child** | When one process starts another, the first is the parent and the new one is the child. The shell is the parent of every command it runs. |
| **`fork()`** | Makes an exact copy of the current process. After it, there are two: the parent and the child. |
| **`execvp()`** | Replaces the current program with a different one (for example, turns the child copy into `ls`). The pid stays the same. |
| **`waitpid()`** | Lets the parent wait until a child finishes, and find out how it ended. |
| **File descriptor (fd)** | A small number a process uses to refer to something open: the keyboard, the screen, a file, or a pipe. Every program reads from **fd 0** (standard input) and writes to **fd 1** (standard output). |
| **`dup2(a, b)`** | Makes fd `b` point to the same thing as fd `a`. This is how output is sent to a file or a pipe instead of the screen. |
| **Pipe** | A one-way channel inside the kernel. What one process writes into it, another can read out. |
| **Built-in** | A command the shell runs itself, without starting a new program (`hop`, `reveal`, `log`, …). |
| **Job** | A command (or pipeline) the shell is tracking, usually one running in the background or paused. |
| **Signal** | A short message the operating system sends to a process, such as "stop" (Ctrl-C) or "pause" (Ctrl-Z). |
| **Process group** | A set of processes that receive signals together. All commands in one pipeline share a group. |

The most important idea: **`fork()` copies a process's file descriptors, and `execvp()` keeps them.**
So the shell can fork, point the child's fd 0 and fd 1 at files or pipes, and then exec the
program. The program just reads fd 0 and writes fd 1 as usual, without knowing anything changed.

## How a command is processed

Every line you type goes through the same six stages, in a loop that runs until you press Ctrl-D.
The loop is `shell_loop()` in `src/shell.c`.

| Stage | Function | What happens | Example |
|---|---|---|---|
| 1. Prompt | `prompt_display()` | Prints `<user@host:path>` | `<sravani@laptop:~>` |
| 2. Read | `read_input()` | Reads one line and removes the newline | `"cat in.txt \| wc -l"` |
| 3. Tokenize | `tokenize()` | Splits the line into words and symbols | `cat` `in.txt` `\|` `wc` `-l` |
| 4. Parse | `parse_input()` | Checks the line follows the grammar and builds a plan | one group with two commands |
| 5. Execute | `execute_shell_cmd()` | Runs the plan | starts `cat` and `wc`, joined by a pipe |
| 6. Output | (the programs) | Output appears on the screen or in a file | `3` |

Two smaller steps also happen every time: just after reading, `jobs_reap_background()` reports
any background jobs that have finished; just after parsing, `history_add()` saves the line for `log`.

### Stage 4 in more detail

The parser does two jobs. It **rejects** lines that don't make sense (printing `Invalid Syntax!`),
and it **builds a plan** that stage 5 follows. The plan has three levels:

```
shell_cmd       the whole line: groups separated by ; or &
 └ cmd_group    commands joined by |, plus a flag saying whether to run in the background
    └ atomic_cmd   one command: its words (argv) and any < > >> files
```

For `cat < in.txt | wc -l ; sleep 5 &` the plan is:

```
group 1 (wait for it)
   cat     argv = [cat]        redirections = [< in.txt]
   wc      argv = [wc, -l]
group 2 (background)
   sleep   argv = [sleep, 5]
```

### Stage 5 in more detail

For each group, the shell asks one question:

- **Is it a single built-in, not in the background?** Then it runs inside the shell itself, with
  no new process. This is required for `hop`: a child process changing directory would not move
  the shell.
- **Otherwise**, the shell starts child processes:

```
for each command in the group:
    if another command follows:  pipe()              make a channel to the next command
    fork()                                           make a child copy of the shell
    in the child:
        open any < > >> files
        dup2() pipe ends and files onto fd 0 / fd 1
        execvp() the program                          becomes ls, cat, wc, ...
    in the parent:
        close the pipe ends it doesn't need
then:
    background group →  add it to the job list, print [n] pid, don't wait
    foreground group →  wait until every child finishes (or Ctrl-Z pauses it)
```

## Command reference

### Prompt
```
<username@systemname:path>
```
- `username` comes from the system's user list (`getpwuid`), `systemname` from `gethostname` (up to the first `.`).
- The directory the shell was started in is its **home** and is shown as `~`.
- Paths inside home are shown as `~/sub/dir`. Any other path is shown in full.

### Grammar
The rules a line must follow:
```
shell_cmd  →  cmd_group ((& | ;) cmd_group)* &?
cmd_group  →  atomic (| atomic)*
atomic     →  name (name | input | output)*
input      →  < name
output     →  > name | >> name
name       →  any characters except | & > < ; and whitespace
```
In plain words:
- A **command** is a name, followed by any mix of arguments and `< file`, `> file`, `>> file`.
- A **group** is one or more commands joined by `|`.
- A **line** is one or more groups separated by `;` or `&`, and may end with `&`.

Spaces between pieces are optional, so `cat<in.txt` and `cat < in.txt` mean the same thing.

| Valid | Invalid | Why it's invalid |
|---|---|---|
| `ls -l` | `ls \|` | a pipe needs a command after it |
| `cat < in.txt \| wc -l > out.txt` | `ls \| \| wc` | two pipes in a row |
| `sleep 5 &` | `ls ;` | `;` needs a group after it (only `&` may end a line) |
| `a ; b & c &` | `cat >` | `>` needs a file name |

### `hop`: change directory
```
hop [~ | . | .. | - | path] ...
```
| Argument | Effect |
|---|---|
| none or `~` | Go to the shell's home |
| `.` | Stay in the current directory |
| `..` | Go to the parent directory (nothing happens at `/`) |
| `-` | Go to the previous directory (nothing happens if there is none yet) |
| `path` | Go to a relative or absolute path |

Several arguments are applied left to right, so `hop src .. -` ends up back in `src`.
A missing directory prints `No such directory!`.

### `reveal`: list a directory
```
reveal [-a] [-l] [~ | . | .. | - | path]
```
- `-a` also shows hidden entries (names starting with `.`).
- `-l` prints one entry per line. Without it, entries are printed on one line, separated by spaces.
- Flags can be combined and repeated: `-la`, `-al`, `-lalala -a`.
- Entries are sorted by ASCII value, so capital letters come first (`Zeta` before `apple`).
- Errors: `No such directory!`, or `reveal: Invalid Syntax!` if more than one directory is given.

### `log`: command history
```
log                  # show saved commands, oldest first
log purge            # clear the history
log execute <i>      # run saved command number i, where 1 is the newest
```
- Up to 15 commands are kept. When the list is full, the oldest is dropped.
- A command is not saved if it is the same as the previous one, or if any command in the line is `log`.
- History is stored in `~/.osn_shell_history`, so it is still there after you restart the shell.
- A command run through `log execute` is not saved again.
- Anything else prints `log: Invalid Syntax!`.

### Other programs
Any name that is not a built-in is run as a normal program, found through `$PATH`
(for example `ls`, `cat`, `grep`, `sleep`). An unknown name prints `Command not found!`.

### Redirection: using files instead of the keyboard or screen
| Syntax | Effect |
|---|---|
| `cmd < file` | `cmd` reads its input from `file` |
| `cmd > file` | `cmd` writes its output to `file`, creating it or emptying it first |
| `cmd >> file` | `cmd` adds its output to the end of `file`, creating it if needed |

Input and output redirection can be used together: `sort < in.txt > out.txt`.
If several of the same kind are given, the last one is used.
Errors: `No such file or directory` (input) and `Unable to create file for writing` (output).
In both cases the command does not run.

### Pipes: connecting commands
```
cmd1 | cmd2 | ... | cmdN
```
The output of each command becomes the input of the next. All the commands run at the same
time, and the prompt returns when all of them have finished. Pipes and redirection can be mixed:
`cat < in.txt | sort > out.txt`.

### Running commands one after another, or in the background
| Syntax | Effect |
|---|---|
| `cmd1 ; cmd2` | Run `cmd1`, wait for it to finish, then run `cmd2`. If `cmd1` fails, `cmd2` still runs. |
| `cmd &` | Start `cmd` in the background and show the prompt again straight away |

When a background job starts, the shell prints `[job_number] pid`, for example `[1] 4242`.
When it finishes, the shell tells you the next time you press Enter:
```
<name> with pid <pid> exited normally
<name> with pid <pid> exited abnormally
```
Background jobs cannot read from the keyboard.

### Managing jobs
| Command or key | What it does | What it prints |
|---|---|---|
| `activities` | Lists running and paused jobs, sorted by command name | `[pid] : name - Running` or `Stopped` |
| `ping <pid> <sig>` | Sends signal number `sig % 32` to process `pid` | `Sent signal <sig> to process with pid <pid>` |
| `fg [n]` | Brings job `n` (or the newest job) to the front and waits for it, resuming it if paused | the full command |
| `bg [n]` | Resumes paused job `n` (or the newest job) in the background | `[n] name &` |
| Ctrl-C | Stops the command running in front. The shell keeps running | |
| Ctrl-Z | Pauses the command running in front and adds it to the job list | `[n] Stopped name` |
| Ctrl-D | Ends every child process and exits the shell | `logout` |

Errors: `No such process found` and `Invalid syntax!` (ping), `No such job` (fg, bg), `Job already running` (bg).

## Source layout

```
shell/
├── Makefile          build rules: `make all`, `make clean`
├── README.md
├── include/          one header (.h) per module: its public functions and types
└── src/
    ├── main.c        entry point; calls shell_loop()
    ├── shell.c       start-up, the main loop, Ctrl-D exit
    ├── prompt.c      the prompt and the shell's home directory   (A.1)
    ├── input.c       reading a line of input                      (A.2)
    ├── tokenizer.c   splitting a line into tokens                 (A.3)
    ├── parser.c      checking the grammar, building the plan      (A.3)
    ├── builtins.c    the list of built-in commands
    ├── hop.c         hop                                          (B.1)
    ├── reveal.c      reveal                                       (B.2)
    ├── log.c         log and saving history                       (B.3)
    ├── executor.c    fork, exec, pipes, ; and &                   (C.1, C.4, D)
    ├── redirect.c    < > >>                                       (C.2, C.3)
    ├── jobs.c        the job list, waiting for and collecting children
    ├── signals.c     Ctrl-C / Ctrl-Z handling, terminal control   (E.3)
    ├── jobctl.c      activities, ping, fg, bg                     (E.1, E.2, E.4)
    └── util.c        safe memory allocation, number parsing
```

How the modules depend on each other, from top to bottom:

| Layer | Modules | Uses |
|---|---|---|
| Front end | `main`, `shell`, `prompt`, `input` | the parser and executor |
| Understanding the line | `tokenizer`, `parser` | `util` |
| Running it | `executor`, `redirect`, `builtins` | the commands, jobs and signals |
| Built-in commands | `hop`, `reveal`, `log`, `jobctl` | jobs (and the parser and executor, for `log execute`) |
| Process management | `jobs`, `signals` | `util` |


 
## Assumptions

The assignment does not define these cases, so these are the choices made.

- **Blank lines** are ignored and do not print `Invalid Syntax!`.
- **Error messages** are printed to standard output.
- **Prompt** ends with a single space after `>`.
- **hop**: if one argument fails, the error is printed and the remaining arguments are still
  processed. `hop .` does not change the previous directory. `~/path` is expanded relative to
  the shell's home.
- **reveal**: flags may appear before or after the directory. An unknown flag such as `-x`
  prints `reveal: Invalid Syntax!`. An empty directory prints nothing.
- **log**: lines are stored exactly as typed, so `echo  hi` and `echo hi` are different entries.
  Lines with invalid syntax are not stored. An out-of-range index for `log execute` prints
  `log: Invalid Syntax!`.
- **Redirection**: all redirection files are opened left to right. Every `>` file is created,
  and a missing `<` file is an error even if a later `<` file exists.
- **Background jobs**: "exited normally" means exit status 0. A non-zero exit status or being
  killed by a signal is "exited abnormally". For a background pipeline, the printed pid is the
  process group id (the first process), and the result is taken from the last command.
- **ping**: the message shows the signal number as typed; the signal actually sent is
  `signal_number % 32`. A non-numeric pid or signal prints `Invalid syntax!`.
- **fg / bg** with no argument use the most recently created job. A new job gets the highest
  current job number plus one.
- **End of piped input** is treated like Ctrl-D, so `logout` is printed.
