#include "util.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

char *wl_strdup(const char *s) {
    if (!s) {
        return NULL;
    }
    size_t n = strlen(s);
    char *out = malloc(n + 1);
    if (!out) {
        return NULL;
    }
    memcpy(out, s, n + 1);
    return out;
}

char *wl_strndup(const char *s, size_t n) {
    if (!s) {
        return NULL;
    }
    char *out = malloc(n + 1);
    if (!out) {
        return NULL;
    }
    memcpy(out, s, n);
    out[n] = '\0';
    return out;
}

void rtrim_inplace(char *s) {
    if (!s) {
        return;
    }
    size_t n = strlen(s);
    while (n > 0 && isspace((unsigned char)s[n - 1])) {
        s[--n] = '\0';
    }
}

char *read_file(const char *path) {
    FILE *f = fopen(path, "rb");
    if (!f) {
        return NULL;
    }
    if (fseek(f, 0, SEEK_END) != 0) {
        fclose(f);
        return NULL;
    }
    long size = ftell(f);
    if (size < 0) {
        fclose(f);
        return NULL;
    }
    if (fseek(f, 0, SEEK_SET) != 0) {
        fclose(f);
        return NULL;
    }
    char *buf = malloc((size_t)size + 1);
    if (!buf) {
        fclose(f);
        return NULL;
    }
    size_t readn = fread(buf, 1, (size_t)size, f);
    fclose(f);
    buf[readn] = '\0';
    return buf;
}

void strlist_init(StrList *list) {
    list->items = NULL;
    list->len = 0;
    list->cap = 0;
}

void strlist_free(StrList *list) {
    if (!list) {
        return;
    }
    for (size_t i = 0; i < list->len; i++) {
        free(list->items[i]);
    }
    free(list->items);
    list->items = NULL;
    list->len = 0;
    list->cap = 0;
}

static int strlist_grow(StrList *list) {
    size_t ncap = list->cap == 0 ? 8 : list->cap * 2;
    char **nitems = realloc(list->items, ncap * sizeof(char *));
    if (!nitems) {
        return -1;
    }
    list->items = nitems;
    list->cap = ncap;
    return 0;
}

int strlist_push_owned(StrList *list, char *s) {
    if (list->len == list->cap && strlist_grow(list) != 0) {
        free(s);
        return -1;
    }
    list->items[list->len++] = s;
    return 0;
}

int strlist_push(StrList *list, const char *s) {
    char *copy = wl_strdup(s);
    if (!copy) {
        return -1;
    }
    return strlist_push_owned(list, copy);
}

char *strlist_join(const StrList *list, const char *sep) {
    size_t sep_len = sep ? strlen(sep) : 0;
    size_t total = 1;
    for (size_t i = 0; i < list->len; i++) {
        total += strlen(list->items[i]);
        if (i + 1 < list->len) {
            total += sep_len;
        }
    }
    char *out = malloc(total);
    if (!out) {
        return NULL;
    }
    out[0] = '\0';
    for (size_t i = 0; i < list->len; i++) {
        strcat(out, list->items[i]);
        if (sep && i + 1 < list->len) {
            strcat(out, sep);
        }
    }
    return out;
}

void dictionaries_init(Dictionaries *dicts) {
    dicts->items = NULL;
    dicts->len = 0;
    dicts->cap = 0;
}

void dictionaries_free(Dictionaries *dicts) {
    if (!dicts) {
        return;
    }
    for (size_t i = 0; i < dicts->len; i++) {
        free(dicts->items[i].name);
        strlist_free(&dicts->items[i].words);
    }
    free(dicts->items);
    dicts->items = NULL;
    dicts->len = 0;
    dicts->cap = 0;
}

int dictionaries_set(Dictionaries *dicts, const char *name, StrList words) {
    for (size_t i = 0; i < dicts->len; i++) {
        if (strcmp(dicts->items[i].name, name) == 0) {
            strlist_free(&dicts->items[i].words);
            dicts->items[i].words = words;
            return 0;
        }
    }
    if (dicts->len == dicts->cap) {
        size_t ncap = dicts->cap == 0 ? 4 : dicts->cap * 2;
        DictEntry *nitems = realloc(dicts->items, ncap * sizeof(DictEntry));
        if (!nitems) {
            strlist_free(&words);
            return -1;
        }
        dicts->items = nitems;
        dicts->cap = ncap;
    }
    dicts->items[dicts->len].name = wl_strdup(name);
    if (!dicts->items[dicts->len].name) {
        strlist_free(&words);
        return -1;
    }
    dicts->items[dicts->len].words = words;
    dicts->len++;
    return 0;
}

const StrList *dictionaries_get(const Dictionaries *dicts, const char *name) {
    for (size_t i = 0; i < dicts->len; i++) {
        if (strcmp(dicts->items[i].name, name) == 0) {
            return &dicts->items[i].words;
        }
    }
    return NULL;
}

bool dictionaries_has(const Dictionaries *dicts, const char *name) {
    return dictionaries_get(dicts, name) != NULL;
}
