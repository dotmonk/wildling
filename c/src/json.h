#ifndef WILDLING_JSON_H
#define WILDLING_JSON_H

#include <stddef.h>
#include <stdbool.h>

typedef enum {
    JSON_NULL,
    JSON_BOOL,
    JSON_NUMBER,
    JSON_STRING,
    JSON_ARRAY,
    JSON_OBJECT
} JsonType;

typedef struct JsonValue JsonValue;

typedef struct {
    char *key;
    JsonValue *value;
} JsonObjectEntry;

struct JsonValue {
    JsonType type;
    bool bool_value;
    double number_value;
    char *string_value;
    JsonValue **array_items;
    size_t array_len;
    JsonObjectEntry *object_entries;
    size_t object_len;
};

JsonValue *json_parse(const char *text);
void json_free(JsonValue *value);
const JsonValue *json_object_get(const JsonValue *obj, const char *key);

#endif
