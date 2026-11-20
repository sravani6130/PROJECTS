#ifndef HOP_H
#define HOP_H

/*
 * hop ((~ | . | .. | - | name)*)?
 * Changes the shell's working directory, applying each argument in order.
 */
void hop_command(int argc, char **argv);

/*
 * The directory we were in before the last successful hop,
 * or NULL if no hop has happened yet. Used by `reveal -`.
 */
const char *hop_prev_dir(void);

#endif /* HOP_H */
