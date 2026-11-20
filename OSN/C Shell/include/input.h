#ifndef INPUT_H
#define INPUT_H

/*
 * Reads one full line of user input from stdin.
 *
 * Returns a pointer to the line with the trailing newline (and any '\r')
 * removed. The buffer is owned by the input module and is reused on the
 * next call — copy it if you need to keep it.
 *
 * Returns NULL on end-of-file (Ctrl-D) or an unrecoverable read error.
 */
char *read_input(void);

/* Frees the internal buffer. Call once when the shell exits. */
void input_cleanup(void);

#endif /* INPUT_H */
