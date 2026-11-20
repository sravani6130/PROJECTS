#ifndef PARSER_H
#define PARSER_H

/*
 * Grammar (from the assignment):
 *   shell_cmd -> cmd_group ((& | ;) cmd_group)* &?
 *   cmd_group -> atomic (| atomic)*
 *   atomic    -> name (name | input | output)*
 *   input     -> < name
 *   output    -> > name | >> name
 *
 * The parser checks the grammar AND builds the structures below,
 * which the execution code (Parts C/D) will use directly.
 */

typedef enum {
    REDIR_INPUT,    /* <  file */
    REDIR_OUTPUT,   /* >  file (truncate) */
    REDIR_APPEND    /* >> file (append)   */
} redir_type;

typedef struct {
    redir_type type;
    char *file;
} redirection;

/* One command with its arguments, e.g.  cat a.txt > out.txt */
typedef struct {
    char **argv;          /* NULL-terminated; argv[0] is the command name */
    int argc;
    redirection *redirs;  /* in the order they appeared */
    int nredirs;
} atomic_cmd;

/* A pipeline, e.g.  cat a.txt | grep x | wc -l */
typedef struct {
    atomic_cmd *cmds;
    int ncmds;
    int background;       /* 1 if this group was followed by '&' */
} cmd_group;

/* A whole input line: groups separated by ';' or '&' */
typedef struct {
    cmd_group *groups;
    int ngroups;
} shell_cmd;

typedef enum {
    PARSE_OK,       /* valid; `out` is filled and must be freed */
    PARSE_EMPTY,    /* blank line; nothing to do, nothing to free */
    PARSE_ERROR     /* invalid syntax; nothing to free */
} parse_status;

parse_status parse_input(const char *line, shell_cmd *out);

void free_shell_cmd(shell_cmd *cmd);

#endif /* PARSER_H */
