#ifndef REVEAL_H
#define REVEAL_H

/*
 * reveal (-(a | l)*)* (~ | . | .. | - | name)?
 *   -a : include hidden entries (names starting with '.')
 *   -l : one entry per line (otherwise space-separated on one line)
 * Entries are sorted lexicographically by ASCII value.
 */
void reveal_command(int argc, char **argv);

#endif /* REVEAL_H */
