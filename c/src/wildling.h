#ifndef WILDLING_WILDLING_H
#define WILDLING_WILDLING_H

#include "generator.h"
#include "util.h"

#define WILDLING_VERSION "2.0.2"

typedef struct {
    Generator *generators;
    size_t generators_len;
    int pattern_count;
    int internal_index;
} Wildling;

int wildling_init(Wildling *w, char **patterns, size_t pattern_count, const Dictionaries *dictionaries);
void wildling_free(Wildling *w);
int wildling_count(const Wildling *w);
void wildling_reset(Wildling *w);
/* returns heap string, or NULL when exhausted/invalid */
char *wildling_next(Wildling *w);
char *wildling_get(const Wildling *w, int index);
const Generator *wildling_generators(const Wildling *w, size_t *out_len);

#endif
