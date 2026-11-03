#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>

int main(void) {
    /* Get the PID of the parent process (the process that forked this child) */
    pid_t ppid = getppid();

    /* Open or create newfile.txt with write permissions */
    FILE *fp = fopen("newfile.txt", "w");
    if (!fp) {
        perror("[writer] Failed to open/create newfile.txt");
        return 1;
    }

    /* Write the parent PID to newfile.txt */
    if (fprintf(fp, "%d\n", (int)ppid) < 0) {
        perror("[writer] Failed to write parent PID to newfile.txt");
        fclose(fp);
        return 1;
    }

    if (fclose(fp) != 0) {
        perror("[writer] Failed to close newfile.txt");
        return 1;
    }

    printf("[writer] Successfully wrote Parent PID (%d) to newfile.txt\n", (int)ppid);
    return 0;
}

