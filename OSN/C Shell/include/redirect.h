#ifndef REDIRECT_H
#define REDIRECT_H

#include "parser.h"

/*
 * Opens every redirection file of `cmd`, in the order written.
 *   <  file : open(O_RDONLY)
 *   >  file : open(O_WRONLY | O_CREAT | O_TRUNC)
 *   >> file : open(O_WRONLY | O_CREAT | O_APPEND)
 * Only the last input and the last output take effect; earlier ones are
 * still opened (so '>' files get created) and then closed.
 *
 * On success: returns 0, *in_fd / *out_fd hold the fds to use (-1 = none).
 * On failure: prints "No such file or directory" or
 *             "Unable to create file for writing", closes everything, returns -1.
 */
int redirect_open(const atomic_cmd *cmd, int *in_fd, int *out_fd);

/* dup2()s the fds onto stdin / stdout and closes the originals. */
void redirect_apply(int in_fd, int out_fd);

#endif /* REDIRECT_H */
