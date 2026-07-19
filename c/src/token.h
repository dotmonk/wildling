#ifndef WILDLING_TOKEN_H
#define WILDLING_TOKEN_H

#include "util.h"

typedef struct {
    char *string; /* optional, may be NULL */
    int start_length;
    int end_length;
    int has_start;
    int has_end;
    StrList variants;
    char *src;
} TokenOptions;

typedef struct {
    char *src;
    int start_length;
    int end_length;
    StrList variants;
    int count;
} Token;

void token_options_init(TokenOptions *opts);
void token_options_free(TokenOptions *opts);

int token_init(Token *token, TokenOptions *opts); /* consumes opts variants/src ownership on success */
void token_free(Token *token);
int token_count(const Token *token);
char *token_get(const Token *token, int index); /* caller frees */

#endif
