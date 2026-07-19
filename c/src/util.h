#ifndef WILDLING_UTIL_H
#define WILDLING_UTIL_H

#include <stddef.h>
#include <stdbool.h>

typedef struct {
    char **items;
    size_t len;
    size_t cap;
} StrList;

typedef struct {
    char *name;
    StrList words;
} DictEntry;

typedef struct {
    DictEntry *items;
    size_t len;
    size_t cap;
} Dictionaries;

void strlist_init(StrList *list);
void strlist_free(StrList *list);
int strlist_push(StrList *list, const char *s);
int strlist_push_owned(StrList *list, char *s);
char *strlist_join(const StrList *list, const char *sep);

void dictionaries_init(Dictionaries *dicts);
void dictionaries_free(Dictionaries *dicts);
int dictionaries_set(Dictionaries *dicts, const char *name, StrList words);
const StrList *dictionaries_get(const Dictionaries *dicts, const char *name);
bool dictionaries_has(const Dictionaries *dicts, const char *name);

char *wl_strdup(const char *s);
char *wl_strndup(const char *s, size_t n);
char *read_file(const char *path);
void rtrim_inplace(char *s);

#endif
