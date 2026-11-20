#include "tokenizer.h"
#include "util.h"

#include <ctype.h>   /* isspace */
#include <stdlib.h>  /* free */
#include <string.h>  /* strlen, strchr */

/* Characters that end a name: the operators and whitespace. */
static int is_delimiter(char c)
{
    return isspace((unsigned char)c) || (c != '\0' && strchr("|&<>;", c) != NULL);
}

void tokenize(const char *line, token_list *out)
{
    size_t n = strlen(line);

    /* A line of n chars has at most n tokens, plus one TOK_END. */
    out->items = xmalloc((n + 1) * sizeof(token));
    out->count = 0;

    size_t i = 0;
    while (i < n) {
        char c = line[i];

        if (isspace((unsigned char)c)) {   /* space, tab, \n, \r ... are skipped */
            i++;
            continue;
        }

        token t = { .type = TOK_WORD, .text = NULL };

        switch (c) {
        case '|': t.type = TOK_PIPE; i++; break;
        case '&': t.type = TOK_AMP;  i++; break;
        case ';': t.type = TOK_SEMI; i++; break;
        case '<': t.type = TOK_LT;   i++; break;
        case '>':
            if (line[i + 1] == '>') {      /* ">>" is one token, not two */
                t.type = TOK_APPEND;
                i += 2;
            } else {
                t.type = TOK_GT;
                i++;
            }
            break;
        default: {                         /* a name: read until a delimiter */
            size_t start = i;
            while (i < n && !is_delimiter(line[i]))
                i++;
            t.type = TOK_WORD;
            t.text = xstrndup(line + start, i - start);
            break;
        }
        }

        out->items[out->count++] = t;
    }

    out->items[out->count++] = (token){ .type = TOK_END, .text = NULL };
}

void free_tokens(token_list *list)
{
    for (int i = 0; i < list->count; i++)
        free(list->items[i].text);
    free(list->items);
    list->items = NULL;
    list->count = 0;
}
