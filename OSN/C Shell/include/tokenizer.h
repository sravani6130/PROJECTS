#ifndef TOKENIZER_H
#define TOKENIZER_H

/* The kinds of tokens the grammar uses. */
typedef enum {
    TOK_WORD,     /* a name: any run of chars that aren't | & > < ; or whitespace */
    TOK_PIPE,     /* |  */
    TOK_AMP,      /* &  */
    TOK_SEMI,     /* ;  */
    TOK_LT,       /* <  */
    TOK_GT,       /* >  */
    TOK_APPEND,   /* >> */
    TOK_END       /* marks the end of the token list */
} token_type;

typedef struct {
    token_type type;
    char *text;   /* only set for TOK_WORD, NULL otherwise */
} token;

typedef struct {
    token *items;
    int count;    /* includes the final TOK_END */
} token_list;

/* Splits `line` into tokens. The list always ends with a TOK_END token. */
void tokenize(const char *line, token_list *out);

void free_tokens(token_list *list);

#endif /* TOKENIZER_H */
