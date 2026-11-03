#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/wait.h>

/*
 * Task 1: Process Creation and Variable Isolation
 * - Defines integer x = 25 in parent.
 * - Child increments x by 10 and prints x with its PID.
 * - Parent decrements x by 5 and prints x with its PID.
 */
static void run_task1(void) {
    printf("========================================\n");
    printf("         TASK 1: VARIABLE ISOLATION     \n");
    printf("========================================\n");

    int x = 25;
    printf("[Task 1] Initial x in Parent (PID: %d) = %d\n", (int)getpid(), x);

    pid_t pid = fork();
    if (pid < 0) {
        perror("[Task 1] fork failed");
        exit(EXIT_FAILURE);
    }

    if (pid == 0) {
        /* Child process */
        x += 10;
        printf("[Task 1] Child  (PID: %d): x incremented by 10 -> x = %d\n", (int)getpid(), x);
        exit(EXIT_SUCCESS);
    } else {
        /* Parent process */
        x -= 5;
        printf("[Task 1] Parent (PID: %d): x decremented by 5  -> x = %d\n", (int)getpid(), x);

        /* Wait for Task 1 child to terminate */
        if (waitpid(pid, NULL, 0) < 0) {
            perror("[Task 1] waitpid failed");
        }
    }
    printf("\n");
}

/*
 * Task 2: Executing External Program (writer)
 * - Parent forks a child.
 * - Child executes ./writer using execvp().
 * - ./writer creates newfile.txt and writes child's parent PID to it.
 * - Parent waits for child and verifies file content.
 */
static void run_task2(void) {
    printf("========================================\n");
    printf("     TASK 2: EXEC EXTERNAL PROGRAM      \n");
    printf("========================================\n");

    pid_t pid = fork();
    if (pid < 0) {
        perror("[Task 2] fork failed");
        exit(EXIT_FAILURE);
    }

    if (pid == 0) {
        /* Child process executes ./writer */
        char *args[] = {"./writer", NULL};
        execvp(args[0], args);

        /* If execvp returns, execution failed */
        perror("[Task 2] execvp failed (ensure ./writer is compiled)");
        exit(EXIT_FAILURE);
    } else {
        /* Parent process waits for child */
        int status;
        if (waitpid(pid, &status, 0) < 0) {
            perror("[Task 2] waitpid failed");
        }

        /* Read and display the content of newfile.txt */
        FILE *fp = fopen("newfile.txt", "r");
        if (!fp) {
            perror("[Task 2] Failed to open newfile.txt for verification");
        } else {
            char buffer[1024];
            if (fgets(buffer, sizeof(buffer), fp) != NULL) {
                buffer[strcspn(buffer, "\r\n")] = '\0';
                printf("[Task 2] Parent (PID: %d) verified newfile.txt contains Parent PID: %s\n",
                       (int)getpid(), buffer);
            }
            fclose(fp);
        }
    }
    printf("\n");
}

/*
 * Task 3: Orphan Process Demonstration
 * - Parent forks a child.
 * - Parent prints its PID and terminates immediately before child.
 * - Child sleeps for 2 seconds, then prints its own PID and new parent PID.
 */
static void run_task3(void) {
    printf("========================================\n");
    printf("       TASK 3: ORPHAN PROCESS DEMO      \n");
    printf("========================================\n");

    pid_t pid = fork();
    if (pid < 0) {
        perror("[Task 3] fork failed");
        exit(EXIT_FAILURE);
    }

    if (pid == 0) {
        /* Child process */
        printf("[Task 3] Child  (PID: %d): Created with initial Parent PID = %d. Sleeping 2 seconds...\n",
               (int)getpid(), (int)getppid());
        sleep(2);
        printf("\n[Task 3] Child  (PID: %d): Woke up!\n", (int)getpid());
        printf("[Task 3] Child  (PID: %d): My PID = %d, Parent PID = %d (Adopted by init/systemd)\n",
               (int)getpid(), (int)getpid(), (int)getppid());
        exit(EXIT_SUCCESS);
    } else {
        /* Parent process terminates before child */
        printf("[Task 3] Parent (PID: %d): Terminating now before child finishes...\n", (int)getpid());
        exit(EXIT_SUCCESS);
    }
}

int main(int argc, char *argv[]) {
    /* If a specific task number is provided as argument (e.g., ./part2 1) */
    if (argc > 1) {
        int task_num = atoi(argv[1]);
        if (task_num == 1) {
            run_task1();
        } else if (task_num == 2) {
            run_task2();
        } else if (task_num == 3) {
            run_task3();
        } else {
            fprintf(stderr, "Usage: %s [1 | 2 | 3]\n", argv[0]);
            return 1;
        }
        return 0;
    }

    run_task1();
    run_task2();
    run_task3();

    return 0;
}

