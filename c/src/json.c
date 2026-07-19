#include "json.h"
#include "util.h"

#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct {
    const char *text;
    size_t pos;
} Parser;

static void skip_ws(Parser *p) {
    while (p->text[p->pos]
           && (p->text[p->pos] == ' ' || p->text[p->pos] == '\n'
               || p->text[p->pos] == '\r' || p->text[p->pos] == '\t')) {
        p->pos++;
    }
}

static int peek(Parser *p, char c) {
    return p->text[p->pos] == c;
}

static int expect(Parser *p, char c) {
    skip_ws(p);
    if (!peek(p, c)) {
        return -1;
    }
    p->pos++;
    return 0;
}

static JsonValue *parse_value(Parser *p);

static char *parse_string(Parser *p) {
    if (expect(p, '"') != 0) {
        return NULL;
    }
    size_t cap = 32;
    size_t len = 0;
    char *out = malloc(cap);
    if (!out) {
        return NULL;
    }
    while (p->text[p->pos]) {
        char c = p->text[p->pos++];
        if (c == '"') {
            out[len] = '\0';
            return out;
        }
        if (c == '\\') {
            char esc = p->text[p->pos++];
            switch (esc) {
                case '"':
                case '\\':
                case '/':
                    c = esc;
                    break;
                case 'b':
                    c = '\b';
                    break;
                case 'f':
                    c = '\f';
                    break;
                case 'n':
                    c = '\n';
                    break;
                case 'r':
                    c = '\r';
                    break;
                case 't':
                    c = '\t';
                    break;
                case 'u': {
                    if (strlen(p->text + p->pos) < 4) {
                        free(out);
                        return NULL;
                    }
                    char hex[5];
                    memcpy(hex, p->text + p->pos, 4);
                    hex[4] = '\0';
                    c = (char)strtol(hex, NULL, 16);
                    p->pos += 4;
                    break;
                }
                default:
                    free(out);
                    return NULL;
            }
        }
        if (len + 1 >= cap) {
            cap *= 2;
            char *n = realloc(out, cap);
            if (!n) {
                free(out);
                return NULL;
            }
            out = n;
        }
        out[len++] = c;
    }
    free(out);
    return NULL;
}

static JsonValue *parse_number(Parser *p) {
    size_t start = p->pos;
    if (peek(p, '-')) {
        p->pos++;
    }
    while (isdigit((unsigned char)p->text[p->pos])) {
        p->pos++;
    }
    if (peek(p, '.')) {
        p->pos++;
        while (isdigit((unsigned char)p->text[p->pos])) {
            p->pos++;
        }
    }
    if (p->text[p->pos] == 'e' || p->text[p->pos] == 'E') {
        p->pos++;
        if (peek(p, '+') || peek(p, '-')) {
            p->pos++;
        }
        while (isdigit((unsigned char)p->text[p->pos])) {
            p->pos++;
        }
    }
    char *raw = wl_strndup(p->text + start, p->pos - start);
    if (!raw) {
        return NULL;
    }
    JsonValue *v = calloc(1, sizeof(JsonValue));
    if (!v) {
        free(raw);
        return NULL;
    }
    v->type = JSON_NUMBER;
    v->number_value = atof(raw);
    free(raw);
    return v;
}

static JsonValue *parse_array(Parser *p) {
    if (expect(p, '[') != 0) {
        return NULL;
    }
    JsonValue *v = calloc(1, sizeof(JsonValue));
    if (!v) {
        return NULL;
    }
    v->type = JSON_ARRAY;
    skip_ws(p);
    if (peek(p, ']')) {
        p->pos++;
        return v;
    }
    size_t cap = 0;
    while (1) {
        JsonValue *item = parse_value(p);
        if (!item) {
            json_free(v);
            return NULL;
        }
        if (v->array_len == cap) {
            size_t ncap = cap == 0 ? 4 : cap * 2;
            JsonValue **nitems = realloc(v->array_items, ncap * sizeof(JsonValue *));
            if (!nitems) {
                json_free(item);
                json_free(v);
                return NULL;
            }
            v->array_items = nitems;
            cap = ncap;
        }
        v->array_items[v->array_len++] = item;
        skip_ws(p);
        if (peek(p, ']')) {
            p->pos++;
            return v;
        }
        if (expect(p, ',') != 0) {
            json_free(v);
            return NULL;
        }
    }
}

static JsonValue *parse_object(Parser *p) {
    if (expect(p, '{') != 0) {
        return NULL;
    }
    JsonValue *v = calloc(1, sizeof(JsonValue));
    if (!v) {
        return NULL;
    }
    v->type = JSON_OBJECT;
    skip_ws(p);
    if (peek(p, '}')) {
        p->pos++;
        return v;
    }
    size_t cap = 0;
    while (1) {
        skip_ws(p);
        char *key = parse_string(p);
        if (!key) {
            json_free(v);
            return NULL;
        }
        skip_ws(p);
        if (expect(p, ':') != 0) {
            free(key);
            json_free(v);
            return NULL;
        }
        JsonValue *value = parse_value(p);
        if (!value) {
            free(key);
            json_free(v);
            return NULL;
        }
        if (v->object_len == cap) {
            size_t ncap = cap == 0 ? 4 : cap * 2;
            JsonObjectEntry *nentries = realloc(v->object_entries, ncap * sizeof(JsonObjectEntry));
            if (!nentries) {
                free(key);
                json_free(value);
                json_free(v);
                return NULL;
            }
            v->object_entries = nentries;
            cap = ncap;
        }
        v->object_entries[v->object_len].key = key;
        v->object_entries[v->object_len].value = value;
        v->object_len++;
        skip_ws(p);
        if (peek(p, '}')) {
            p->pos++;
            return v;
        }
        if (expect(p, ',') != 0) {
            json_free(v);
            return NULL;
        }
    }
}

static JsonValue *parse_value(Parser *p) {
    skip_ws(p);
    char c = p->text[p->pos];
    if (c == '{') {
        return parse_object(p);
    }
    if (c == '[') {
        return parse_array(p);
    }
    if (c == '"') {
        char *s = parse_string(p);
        if (!s) {
            return NULL;
        }
        JsonValue *v = calloc(1, sizeof(JsonValue));
        if (!v) {
            free(s);
            return NULL;
        }
        v->type = JSON_STRING;
        v->string_value = s;
        return v;
    }
    if (c == 't' && strncmp(p->text + p->pos, "true", 4) == 0) {
        p->pos += 4;
        JsonValue *v = calloc(1, sizeof(JsonValue));
        if (!v) {
            return NULL;
        }
        v->type = JSON_BOOL;
        v->bool_value = true;
        return v;
    }
    if (c == 'f' && strncmp(p->text + p->pos, "false", 5) == 0) {
        p->pos += 5;
        JsonValue *v = calloc(1, sizeof(JsonValue));
        if (!v) {
            return NULL;
        }
        v->type = JSON_BOOL;
        v->bool_value = false;
        return v;
    }
    if (c == 'n' && strncmp(p->text + p->pos, "null", 4) == 0) {
        p->pos += 4;
        JsonValue *v = calloc(1, sizeof(JsonValue));
        if (!v) {
            return NULL;
        }
        v->type = JSON_NULL;
        return v;
    }
    if (c == '-' || isdigit((unsigned char)c)) {
        return parse_number(p);
    }
    return NULL;
}

JsonValue *json_parse(const char *text) {
    Parser p = {text, 0};
    JsonValue *v = parse_value(&p);
    if (!v) {
        return NULL;
    }
    skip_ws(&p);
    if (p.text[p.pos] != '\0') {
        json_free(v);
        return NULL;
    }
    return v;
}

void json_free(JsonValue *value) {
    if (!value) {
        return;
    }
    if (value->type == JSON_STRING) {
        free(value->string_value);
    } else if (value->type == JSON_ARRAY) {
        for (size_t i = 0; i < value->array_len; i++) {
            json_free(value->array_items[i]);
        }
        free(value->array_items);
    } else if (value->type == JSON_OBJECT) {
        for (size_t i = 0; i < value->object_len; i++) {
            free(value->object_entries[i].key);
            json_free(value->object_entries[i].value);
        }
        free(value->object_entries);
    }
    free(value);
}

const JsonValue *json_object_get(const JsonValue *obj, const char *key) {
    if (!obj || obj->type != JSON_OBJECT) {
        return NULL;
    }
    for (size_t i = 0; i < obj->object_len; i++) {
        if (strcmp(obj->object_entries[i].key, key) == 0) {
            return obj->object_entries[i].value;
        }
    }
    return NULL;
}
