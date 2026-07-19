#ifndef WILDLING_GENERATOR_H
#define WILDLING_GENERATOR_H

#include "parse_pattern.h"
#include "util.h"

typedef struct {
    char *source;
    TokenList tokens;
    int count;
} Generator;

int generator_init(Generator *gen, const char *input_pattern, const Dictionaries *dictionaries);
void generator_free(Generator *gen);
int generator_count(const Generator *gen);
char *generator_get(const Generator *gen, int index); /* caller frees */

#endif
