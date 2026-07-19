#include "parse_pattern.h"

#include <regex.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

void tokenlist_free(TokenList *list) {
    if (!list) {
        return;
    }
    for (size_t i = 0; i < list->len; i++) {
        token_free(&list->items[i]);
    }
    free(list->items);
    list->items = NULL;
    list->len = 0;
    list->cap = 0;
}

static int tokenlist_push(TokenList *list, Token token) {
    if (list->len == list->cap) {
        size_t ncap = list->cap == 0 ? 4 : list->cap * 2;
        Token *nitems = realloc(list->items, ncap * sizeof(Token));
        if (!nitems) {
            token_free(&token);
            return -1;
        }
        list->items = nitems;
        list->cap = ncap;
    }
    list->items[list->len++] = token;
    return 0;
}

static int chars_as_variants(const char *variants_string, StrList *out) {
    strlist_init(out);
    for (const char *p = variants_string; *p; p++) {
        char buf[2] = {*p, '\0'};
        if (strlist_push(out, buf) != 0) {
            strlist_free(out);
            return -1;
        }
    }
    return 0;
}

static int parse_length_with_variants(const char *part, StrList variants, TokenOptions *opts) {
    token_options_init(opts);
    opts->variants = variants;
    opts->src = wl_strdup(part);
    if (!opts->src) {
        strlist_free(&opts->variants);
        return -1;
    }

    regex_t re;
    if (regcomp(&re, "\\{(([0-9]+)-([0-9]+)|([0-9]+))\\}", REG_EXTENDED) != 0) {
        token_options_free(opts);
        return -1;
    }
    regmatch_t m[5];
    if (regexec(&re, part, 5, m, 0) == 0) {
        if (m[2].rm_so >= 0 && m[2].rm_eo > m[2].rm_so) {
            opts->start_length = atoi(part + m[2].rm_so);
            opts->end_length = atoi(part + m[3].rm_so);
            opts->has_start = 1;
            opts->has_end = 1;
        } else if (m[1].rm_so >= 0) {
            opts->start_length = atoi(part + m[1].rm_so);
            opts->end_length = opts->start_length;
            opts->has_start = 1;
            opts->has_end = 1;
        }
    }
    regfree(&re);
    return 0;
}

/* returns 1 if matched, 0 if not, -1 on error */
static int parse_length_with_string(const char *part, TokenOptions *opts) {
    token_options_init(opts);
    regex_t re;
    if (regcomp(&re, "\\{'(.*)'(,([0-9]+)-([0-9]+))?(,([0-9]+))?\\}", REG_EXTENDED) != 0) {
        return -1;
    }

    regmatch_t m[7];
    if (regexec(&re, part, 7, m, 0) != 0) {
        regfree(&re);
        token_options_free(opts);
        return 0;
    }

    opts->src = wl_strdup(part);
    if (!opts->src) {
        regfree(&re);
        token_options_free(opts);
        return -1;
    }

    size_t slen = (size_t)(m[1].rm_eo - m[1].rm_so);
    opts->string = wl_strndup(part + m[1].rm_so, slen);
    if (!opts->string) {
        regfree(&re);
        token_options_free(opts);
        return -1;
    }

    if (m[3].rm_so >= 0 && m[4].rm_so >= 0 && m[3].rm_eo > m[3].rm_so) {
        opts->start_length = atoi(part + m[3].rm_so);
        opts->end_length = atoi(part + m[4].rm_so);
        opts->has_start = 1;
        opts->has_end = 1;
    } else if (m[6].rm_so >= 0 && m[6].rm_eo > m[6].rm_so) {
        int length = atoi(part + m[6].rm_so);
        opts->start_length = length;
        opts->end_length = length;
        opts->has_start = 1;
        opts->has_end = 1;
    } else {
        opts->start_length = 1;
        opts->end_length = 1;
        opts->has_start = 1;
        opts->has_end = 1;
    }

    regfree(&re);
    return 1;
}

static int make_literal_token(const char *part, Token *out) {
    TokenOptions opts;
    token_options_init(&opts);
    opts.src = wl_strdup(part);
    if (!opts.src || strlist_push(&opts.variants, part) != 0) {
        token_options_free(&opts);
        return -1;
    }
    opts.has_start = 1;
    opts.has_end = 1;
    opts.start_length = 1;
    opts.end_length = 1;
    return token_init(out, &opts);
}

static int dictionary_tokenizer(const char *part, const Dictionaries *dictionaries, Token *out) {
    TokenOptions opts;
    int matched = parse_length_with_string(part, &opts);
    if (matched < 0) {
        return -1;
    }
    if (matched == 0
        || (opts.string && opts.string[0] != '\0' && !dictionaries_has(dictionaries, opts.string))) {
        token_options_free(&opts);
        return make_literal_token(part, out);
    }

    const StrList *words = dictionaries_get(dictionaries, opts.string ? opts.string : "");
    strlist_init(&opts.variants);
    if (words) {
        for (size_t i = 0; i < words->len; i++) {
            if (strlist_push(&opts.variants, words->items[i]) != 0) {
                token_options_free(&opts);
                return -1;
            }
        }
    }
    return token_init(out, &opts);
}

static int words_tokenizer(const char *part, Token *out) {
    TokenOptions opts;
    int matched = parse_length_with_string(part, &opts);
    if (matched < 0) {
        return -1;
    }
    if (matched == 0) {
        token_options_free(&opts);
        return make_literal_token(part, out);
    }

    StrList variants;
    strlist_init(&variants);
    char *work = wl_strdup(opts.string ? opts.string : "");
    if (!work) {
        token_options_free(&opts);
        return -1;
    }

    size_t index = 0;
    while (index < strlen(work)) {
        if (index + 1 < strlen(work) && work[index] == '\\' && work[index + 1] == ',') {
            index += 2;
        } else if (work[index] == ',') {
            char *piece = wl_strndup(work, index);
            if (!piece || strlist_push_owned(&variants, piece) != 0) {
                free(work);
                strlist_free(&variants);
                token_options_free(&opts);
                return -1;
            }
            char *rest = wl_strdup(work + index + 1);
            free(work);
            work = rest;
            if (!work) {
                strlist_free(&variants);
                token_options_free(&opts);
                return -1;
            }
            index = 0;
        } else {
            index++;
        }
    }
    if (strlist_push_owned(&variants, work) != 0) {
        strlist_free(&variants);
        token_options_free(&opts);
        return -1;
    }

    for (size_t i = 0; i < variants.len; i++) {
        char *v = variants.items[i];
        char *dst = v;
        for (char *src = v; *src; src++) {
            if (src[0] == '\\' && src[1] == ',') {
                *dst++ = ',';
                src++;
            } else {
                *dst++ = *src;
            }
        }
        *dst = '\0';
    }

    opts.variants = variants;
    return token_init(out, &opts);
}

static int simple_tokenizer(const char *part, const char *alphabet, Token *out) {
    StrList variants;
    if (chars_as_variants(alphabet, &variants) != 0) {
        return -1;
    }
    TokenOptions opts;
    if (parse_length_with_variants(part, variants, &opts) != 0) {
        return -1;
    }
    return token_init(out, &opts);
}

static int is_special(char c) {
    return strchr("#@$*&?!-%", c) != NULL;
}

static int part_to_token(const char *part, const Dictionaries *dictionaries, Token *out) {
    if (part[0] == '\0') {
        return make_literal_token(part, out);
    }

    char c = part[0];
    if (c == '#') {
        return simple_tokenizer(part, "0123456789", out);
    }
    if (c == '@') {
        return simple_tokenizer(part, "abcdefghijklmnopqrstuvwxyz", out);
    }
    if (c == '*') {
        return simple_tokenizer(part, "abcdefghijklmnopqrstuvwxyz0123456789", out);
    }
    if (c == '-') {
        return simple_tokenizer(
            part,
            "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789",
            out);
    }
    if (c == '!') {
        return simple_tokenizer(part, "ABCDEFGHIJKLMNOPQRSTUVWXYZ", out);
    }
    if (c == '?') {
        return simple_tokenizer(part, "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789", out);
    }
    if (c == '&') {
        return simple_tokenizer(
            part, "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ", out);
    }
    if (c == '%') {
        return dictionary_tokenizer(part, dictionaries, out);
    }
    if (c == '$') {
        return words_tokenizer(part, out);
    }

    if (part[0] == '\\' && part[1] != '\0' && is_special(part[1])) {
        TokenOptions opts;
        token_options_init(&opts);
        opts.src = wl_strdup(part);
        if (!opts.src || strlist_push(&opts.variants, part + 1) != 0) {
            token_options_free(&opts);
            return -1;
        }
        opts.has_start = 1;
        opts.has_end = 1;
        opts.start_length = 1;
        opts.end_length = 1;
        return token_init(out, &opts);
    }

    return make_literal_token(part, out);
}

static int split_keeping_delimiters(const char *input, StrList *parts) {
    strlist_init(parts);
    regex_t re;
    if (regcomp(&re, "(\\\\[%@$*#&?!-]|[%@$*#&?!-]\\{[^}]*\\}|[%@$*#&?!-])", REG_EXTENDED) != 0) {
        return -1;
    }

    const char *cursor = input;
    while (*cursor) {
        regmatch_t m[2];
        if (regexec(&re, cursor, 2, m, 0) != 0) {
            if (strlist_push(parts, cursor) != 0) {
                regfree(&re);
                strlist_free(parts);
                return -1;
            }
            break;
        }
        if (m[0].rm_so > 0) {
            char *before = wl_strndup(cursor, (size_t)m[0].rm_so);
            if (!before || strlist_push_owned(parts, before) != 0) {
                free(before);
                regfree(&re);
                strlist_free(parts);
                return -1;
            }
        }
        char *token = wl_strndup(cursor + m[1].rm_so, (size_t)(m[1].rm_eo - m[1].rm_so));
        if (!token || strlist_push_owned(parts, token) != 0) {
            free(token);
            regfree(&re);
            strlist_free(parts);
            return -1;
        }
        cursor += m[0].rm_eo;
    }

    regfree(&re);
    return 0;
}

int parse_pattern(const char *input_pattern, const Dictionaries *dictionaries, TokenList *out) {
    out->items = NULL;
    out->len = 0;
    out->cap = 0;

    StrList parts;
    if (split_keeping_delimiters(input_pattern, &parts) != 0) {
        return -1;
    }

    for (size_t i = 0; i < parts.len; i++) {
        if (parts.items[i][0] == '\0') {
            continue;
        }
        Token token;
        if (part_to_token(parts.items[i], dictionaries, &token) != 0) {
            strlist_free(&parts);
            tokenlist_free(out);
            return -1;
        }
        if (tokenlist_push(out, token) != 0) {
            strlist_free(&parts);
            tokenlist_free(out);
            return -1;
        }
    }

    strlist_free(&parts);
    return 0;
}
