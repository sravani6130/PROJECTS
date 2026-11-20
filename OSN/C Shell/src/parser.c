#include "parser.h"
#include "tokenizer.h"
#include "util.h"

#include <stdlib.h>  /* free */
#include <string.h>  /* memset */

/* Parser state: the token list and our position in it. */
typedef struct {
    const token_list *toks;
    int pos;
} parser;

static token_type peek(const parser *p)
{
    return p->toks->items[p->pos].type;
}

/* Consumes the current token and returns it. Never moves past TOK_END. */
static const token *advance(parser *p)
{
    const token *t = &p->toks->items[p->pos];
    if (t->type != TOK_END)
        p->pos++;
    return t;
}

/* Makes sure an array has room for `needed` elements, doubling its capacity. */
static void *ensure_capacity(void *arr, int needed, int *cap, size_t elem_size)
{
    if (needed <= *cap)
        return arr;
    int new_cap = (*cap == 0) ? 4 : *cap;
    while (new_cap < needed)
        new_cap *= 2;
    *cap = new_cap;
    return xrealloc(arr, (size_t)new_cap * elem_size);
}

/* ---------- atomic -> name (name | input | output)* ---------- */

static void add_arg(atomic_cmd *a, int *cap, const char *word)
{
    /* +2: the new argument plus the terminating NULL */
    a->argv = ensure_capacity(a->argv, a->argc + 2, cap, sizeof(char *));
    a->argv[a->argc++] = xstrdup(word);
    a->argv[a->argc] = NULL;
}

static void add_redir(atomic_cmd *a, int *cap, redir_type type, const char *file)
{
    a->redirs = ensure_capacity(a->redirs, a->nredirs + 1, cap, sizeof(redirection));
    a->redirs[a->nredirs].type = type;
    a->redirs[a->nredirs].file = xstrdup(file);
    a->nredirs++;
}

static int parse_atomic(parser *p, atomic_cmd *a)
{
    int argv_cap = 0, redir_cap = 0;

    /* Must start with a name (the command itself). */
    if (peek(p) != TOK_WORD)
        return -1;
    add_arg(a, &argv_cap, advance(p)->text);

    while (1) {
        token_type t = peek(p);

        if (t == TOK_WORD) {                       /* another argument */
            add_arg(a, &argv_cap, advance(p)->text);
        } else if (t == TOK_LT || t == TOK_GT || t == TOK_APPEND) {
            advance(p);
            if (peek(p) != TOK_WORD)               /* redirection needs a file name */
                return -1;
            redir_type type = (t == TOK_LT) ? REDIR_INPUT
                            : (t == TOK_GT) ? REDIR_OUTPUT
                            : REDIR_APPEND;
            add_redir(a, &redir_cap, type, advance(p)->text);
        } else {
            return 0;                              /* |, &, ; or end: atomic is done */
        }
    }
}

/* ---------- cmd_group -> atomic (| atomic)* ---------- */

static int parse_cmd_group(parser *p, cmd_group *g)
{
    int cap = 0;

    while (1) {
        g->cmds = ensure_capacity(g->cmds, g->ncmds + 1, &cap, sizeof(atomic_cmd));
        atomic_cmd *a = &g->cmds[g->ncmds++];   /* counted now so it's freed on error */
        memset(a, 0, sizeof(*a));

        if (parse_atomic(p, a) != 0)
            return -1;

        if (peek(p) != TOK_PIPE)
            return 0;
        advance(p);                             /* consume '|', another atomic must follow */
    }
}

/* ---------- shell_cmd -> cmd_group ((& | ;) cmd_group)* &? ---------- */

static int parse_shell_cmd(parser *p, shell_cmd *s)
{
    int cap = 0;

    while (1) {
        s->groups = ensure_capacity(s->groups, s->ngroups + 1, &cap, sizeof(cmd_group));
        cmd_group *g = &s->groups[s->ngroups++];
        memset(g, 0, sizeof(*g));

        if (parse_cmd_group(p, g) != 0)
            return -1;

        token_type t = peek(p);
        if (t == TOK_END)
            return 0;

        if (t == TOK_SEMI) {
            advance(p);          /* ';' must be followed by another cmd_group */
            continue;
        }

        if (t == TOK_AMP) {
            advance(p);
            g->background = 1;
            if (peek(p) == TOK_END)
                return 0;        /* trailing '&' is allowed */
            continue;            /* otherwise another cmd_group must follow */
        }

        return -1;               /* unreachable for valid tokens, kept for safety */
    }
}

/* ---------- public API ---------- */

parse_status parse_input(const char *line, shell_cmd *out)
{
    memset(out, 0, sizeof(*out));

    token_list toks;
    tokenize(line, &toks);

    if (toks.count == 1) {       /* only TOK_END: blank line */
        free_tokens(&toks);
        return PARSE_EMPTY;
    }

    parser p = { .toks = &toks, .pos = 0 };
    int rc = parse_shell_cmd(&p, out);
    free_tokens(&toks);

    if (rc != 0) {
        free_shell_cmd(out);
        return PARSE_ERROR;
    }
    return PARSE_OK;
}

void free_shell_cmd(shell_cmd *cmd)
{
    for (int i = 0; i < cmd->ngroups; i++) {
        cmd_group *g = &cmd->groups[i];
        for (int j = 0; j < g->ncmds; j++) {
            atomic_cmd *a = &g->cmds[j];
            for (int k = 0; k < a->argc; k++)
                free(a->argv[k]);
            free(a->argv);
            for (int k = 0; k < a->nredirs; k++)
                free(a->redirs[k].file);
            free(a->redirs);
        }
        free(g->cmds);
    }
    free(cmd->groups);
    memset(cmd, 0, sizeof(*cmd));
}
