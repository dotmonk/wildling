#include "token.h"

#include <stdlib.h>
#include <string.h>

void token_options_init(TokenOptions *opts) {
    opts->string = NULL;
    opts->start_length = 1;
    opts->end_length = 1;
    opts->has_start = 0;
    opts->has_end = 0;
    strlist_init(&opts->variants);
    opts->src = NULL;
}

void token_options_free(TokenOptions *opts) {
    free(opts->string);
    free(opts->src);
    strlist_free(&opts->variants);
    opts->string = NULL;
    opts->src = NULL;
}

static int default_integer(int has, int value, int fallback) {
    return has && value >= 0 ? value : fallback;
}

static int pow_int(int base, int exp) {
    int result = 1;
    for (int i = 0; i < exp; i++) {
        result *= base;
    }
    return result;
}

int token_init(Token *token, TokenOptions *opts) {
    token->src = opts->src ? opts->src : wl_strdup("");
    opts->src = NULL;
    if (!token->src) {
        return -1;
    }
    token->start_length = default_integer(opts->has_start, opts->start_length, 1);
    token->end_length = default_integer(opts->has_end, opts->end_length, 1);
    token->variants = opts->variants;
    opts->variants.items = NULL;
    opts->variants.len = 0;
    opts->variants.cap = 0;

    int count = 0;
    for (int length = token->start_length; length <= token->end_length; length++) {
        count += pow_int((int)token->variants.len, length);
    }
    token->count = count;

    free(opts->string);
    opts->string = NULL;
    return 0;
}

void token_free(Token *token) {
    free(token->src);
    strlist_free(&token->variants);
    token->src = NULL;
}

int token_count(const Token *token) {
    return token->count;
}

char *token_get(const Token *token, int index) {
    if (index > token->count - 1 || index < 0) {
        return wl_strdup("");
    }
    if (index == 0 && token->start_length == 0) {
        return wl_strdup("");
    }

    int index_with_offset = index;
    int string_length = token->start_length;
    for (string_length = token->start_length; string_length <= token->end_length; string_length++) {
        int offset_count = pow_int((int)token->variants.len, string_length);
        if (index_with_offset < offset_count) {
            break;
        }
        index_with_offset -= offset_count;
    }

    size_t total = 1;
    int temp = index_with_offset;
    for (int i = 0; i < string_length; i++) {
        int variant_index = temp % (int)token->variants.len;
        temp /= (int)token->variants.len;
        total += strlen(token->variants.items[variant_index]);
    }

    char *out = malloc(total);
    if (!out) {
        return NULL;
    }
    out[0] = '\0';
    for (int i = 0; i < string_length; i++) {
        int variant_index = index_with_offset % (int)token->variants.len;
        index_with_offset /= (int)token->variants.len;
        strcat(out, token->variants.items[variant_index]);
    }
    return out;
}
