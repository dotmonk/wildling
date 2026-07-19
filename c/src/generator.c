#include "generator.h"

#include <stdlib.h>
#include <string.h>

int generator_init(Generator *gen, const char *input_pattern, const Dictionaries *dictionaries) {
    gen->source = wl_strdup(input_pattern);
    if (!gen->source) {
        return -1;
    }
    if (parse_pattern(input_pattern, dictionaries, &gen->tokens) != 0) {
        free(gen->source);
        gen->source = NULL;
        return -1;
    }
    int count = 1;
    for (size_t i = 0; i < gen->tokens.len; i++) {
        count *= token_count(&gen->tokens.items[i]);
    }
    gen->count = count;
    return 0;
}

void generator_free(Generator *gen) {
    free(gen->source);
    tokenlist_free(&gen->tokens);
    gen->source = NULL;
}

int generator_count(const Generator *gen) {
    return gen->count;
}

char *generator_get(const Generator *gen, int index) {
    if (index > gen->count - 1 || index < 0) {
        return wl_strdup("");
    }

    StrList parts;
    strlist_init(&parts);
    int index_with_offset = index;
    for (size_t i = 0; i < gen->tokens.len; i++) {
        const Token *token = &gen->tokens.items[i];
        char *piece = token_get(token, index_with_offset % token_count(token));
        if (!piece || strlist_push_owned(&parts, piece) != 0) {
            free(piece);
            strlist_free(&parts);
            return NULL;
        }
        index_with_offset /= token_count(token);
    }
    char *out = strlist_join(&parts, "");
    strlist_free(&parts);
    return out;
}
