#ifndef WILDLING_PARSE_PATTERN_H
#define WILDLING_PARSE_PATTERN_H

#include "token.h"
#include "util.h"

typedef struct {
    Token *items;
    size_t len;
    size_t cap;
} TokenList;

void tokenlist_free(TokenList *list);
int parse_pattern(const char *input_pattern, const Dictionaries *dictionaries, TokenList *out);

#endif
