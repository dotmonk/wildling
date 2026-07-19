#include "wildling.h"

#include <stdlib.h>

int wildling_init(Wildling *w, char **patterns, size_t pattern_count, const Dictionaries *dictionaries) {
    w->generators = NULL;
    w->generators_len = 0;
    w->pattern_count = 0;
    w->internal_index = 0;

    if (pattern_count == 0) {
        return 0;
    }

    w->generators = calloc(pattern_count, sizeof(Generator));
    if (!w->generators) {
        return -1;
    }

    for (size_t i = 0; i < pattern_count; i++) {
        if (generator_init(&w->generators[i], patterns[i], dictionaries) != 0) {
            for (size_t j = 0; j < i; j++) {
                generator_free(&w->generators[j]);
            }
            free(w->generators);
            w->generators = NULL;
            return -1;
        }
        w->pattern_count += generator_count(&w->generators[i]);
        w->generators_len++;
    }
    return 0;
}

void wildling_free(Wildling *w) {
    if (!w || !w->generators) {
        return;
    }
    for (size_t i = 0; i < w->generators_len; i++) {
        generator_free(&w->generators[i]);
    }
    free(w->generators);
    w->generators = NULL;
    w->generators_len = 0;
}

int wildling_count(const Wildling *w) {
    return w->pattern_count;
}

void wildling_reset(Wildling *w) {
    w->internal_index = 0;
}

char *wildling_get(const Wildling *w, int index) {
    if (index > w->pattern_count - 1 || index < 0) {
        return NULL;
    }
    int segment_index = 0;
    for (size_t i = 0; i < w->generators_len; i++) {
        int pattern_index = index - segment_index;
        if (pattern_index < generator_count(&w->generators[i])) {
            return generator_get(&w->generators[i], pattern_index);
        }
        segment_index += generator_count(&w->generators[i]);
    }
    return NULL;
}

char *wildling_next(Wildling *w) {
    if (w->internal_index == w->pattern_count) {
        return NULL;
    }
    w->internal_index += 1;
    return wildling_get(w, w->internal_index - 1);
}

const Generator *wildling_generators(const Wildling *w, size_t *out_len) {
    if (out_len) {
        *out_len = w->generators_len;
    }
    return w->generators;
}
