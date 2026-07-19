#include "json.h"
#include "util.h"
#include "wildling.h"

#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>

typedef struct {
    int start;
    int end;
} Range;

typedef struct {
    int *selects;
    size_t selects_len;
    size_t selects_cap;
    Range *ranges;
    size_t ranges_len;
    size_t ranges_cap;
    bool check;
    Dictionaries dictionaries;
    StrList patterns;
    bool help;
    bool version;
} CliArgs;

static void cliargs_init(CliArgs *a) {
    memset(a, 0, sizeof(*a));
    dictionaries_init(&a->dictionaries);
    strlist_init(&a->patterns);
}

static void cliargs_free(CliArgs *a) {
    free(a->selects);
    free(a->ranges);
    dictionaries_free(&a->dictionaries);
    strlist_free(&a->patterns);
}

static int push_select(CliArgs *a, int v) {
    if (a->selects_len == a->selects_cap) {
        size_t ncap = a->selects_cap == 0 ? 4 : a->selects_cap * 2;
        int *n = realloc(a->selects, ncap * sizeof(int));
        if (!n) {
            return -1;
        }
        a->selects = n;
        a->selects_cap = ncap;
    }
    a->selects[a->selects_len++] = v;
    return 0;
}

static int push_range(CliArgs *a, Range r) {
    if (a->ranges_len == a->ranges_cap) {
        size_t ncap = a->ranges_cap == 0 ? 4 : a->ranges_cap * 2;
        Range *n = realloc(a->ranges, ncap * sizeof(Range));
        if (!n) {
            return -1;
        }
        a->ranges = n;
        a->ranges_cap = ncap;
    }
    a->ranges[a->ranges_len++] = r;
    return 0;
}

static bool parse_range(const char *value, Range *out) {
    const char *dash = strchr(value, '-');
    if (!dash || dash == value || dash[1] == '\0') {
        return false;
    }
    for (const char *p = value; p < dash; p++) {
        if (!isdigit((unsigned char)*p)) {
            return false;
        }
    }
    for (const char *p = dash + 1; *p; p++) {
        if (!isdigit((unsigned char)*p)) {
            return false;
        }
    }
    int start = atoi(value);
    int end = atoi(dash + 1);
    if (start > end) {
        return false;
    }
    out->start = start;
    out->end = end;
    return true;
}

static int load_dictionary_file(const char *path, StrList *out) {
    strlist_init(out);
    char *content = read_file(path);
    if (!content) {
        return -1;
    }
    char *cursor = content;
    while (*cursor) {
        char *line_end = cursor;
        while (*line_end && *line_end != '\n' && *line_end != '\r') {
            line_end++;
        }
        char saved = *line_end;
        *line_end = '\0';
        while (*cursor && isspace((unsigned char)*cursor)) {
            cursor++;
        }
        char *end = line_end;
        while (end > cursor && isspace((unsigned char)end[-1])) {
            end--;
        }
        *end = '\0';
        if (*cursor) {
            if (strlist_push(out, cursor) != 0) {
                free(content);
                strlist_free(out);
                return -1;
            }
        }
        *line_end = saved;
        cursor = line_end;
        if (*cursor == '\r') {
            cursor++;
        }
        if (*cursor == '\n') {
            cursor++;
        }
    }
    free(content);
    return 0;
}

static void apply_dictionary_path(CliArgs *result, const char *name, const char *path) {
    FILE *f = fopen(path, "r");
    if (!f) {
        return;
    }
    fclose(f);
    StrList words;
    if (load_dictionary_file(path, &words) == 0) {
        dictionaries_set(&result->dictionaries, name, words);
    }
}

static void apply_dictionary_json(CliArgs *result, const char *name, const JsonValue *value) {
    if (value->type == JSON_ARRAY) {
        StrList words;
        strlist_init(&words);
        for (size_t i = 0; i < value->array_len; i++) {
            const JsonValue *item = value->array_items[i];
            if (item->type == JSON_STRING) {
                strlist_push(&words, item->string_value);
            } else if (item->type == JSON_NUMBER) {
                char buf[64];
                snprintf(buf, sizeof(buf), "%lld", (long long)item->number_value);
                strlist_push(&words, buf);
            } else if (item->type == JSON_BOOL) {
                strlist_push(&words, item->bool_value ? "true" : "false");
            }
        }
        dictionaries_set(&result->dictionaries, name, words);
        return;
    }
    if (value->type == JSON_STRING) {
        apply_dictionary_path(result, name, value->string_value);
    }
}

static void apply_template(CliArgs *result, const char *path) {
    char *raw = read_file(path);
    if (!raw) {
        fprintf(stderr, "Template file not found: %s\n", path);
        exit(1);
    }
    JsonValue *root = json_parse(raw);
    free(raw);
    if (!root || root->type != JSON_OBJECT) {
        json_free(root);
        fprintf(stderr, "Invalid JSON template: %s\n", path);
        exit(1);
    }

    const JsonValue *check = json_object_get(root, "check");
    if (check && check->type == JSON_BOOL && check->bool_value) {
        result->check = true;
    }

    const JsonValue *select = json_object_get(root, "select");
    if (select && select->type == JSON_ARRAY) {
        for (size_t i = 0; i < select->array_len; i++) {
            const JsonValue *val = select->array_items[i];
            int number = -1;
            if (val->type == JSON_NUMBER) {
                number = (int)val->number_value;
            } else if (val->type == JSON_STRING) {
                number = atoi(val->string_value);
            }
            if (number >= 0) {
                push_select(result, number);
            }
        }
    }

    const JsonValue *ranges = json_object_get(root, "range");
    if (ranges && ranges->type == JSON_ARRAY) {
        for (size_t i = 0; i < ranges->array_len; i++) {
            const JsonValue *val = ranges->array_items[i];
            if (val->type == JSON_STRING) {
                Range r;
                if (parse_range(val->string_value, &r)) {
                    push_range(result, r);
                }
            }
        }
    }

    const JsonValue *dicts = json_object_get(root, "dictionaries");
    if (dicts && dicts->type == JSON_OBJECT) {
        for (size_t i = 0; i < dicts->object_len; i++) {
            apply_dictionary_json(result, dicts->object_entries[i].key, dicts->object_entries[i].value);
        }
    }

    const JsonValue *patterns = json_object_get(root, "patterns");
    if (patterns && patterns->type == JSON_ARRAY) {
        for (size_t i = 0; i < patterns->array_len; i++) {
            const JsonValue *val = patterns->array_items[i];
            if (val->type == JSON_STRING) {
                strlist_push(&result->patterns, val->string_value);
            }
        }
    }

    json_free(root);
}

static void parse_args(int argc, char **argv, CliArgs *result) {
    cliargs_init(result);
    for (int i = 1; i < argc; i++) {
        const char *arg = argv[i];
        if (strcmp(arg, "--help") == 0 || strcmp(arg, "-h") == 0) {
            result->help = true;
            continue;
        }
        if (strcmp(arg, "--version") == 0 || strcmp(arg, "-v") == 0) {
            result->version = true;
            continue;
        }
        if (strcmp(arg, "--check") == 0) {
            result->check = true;
            continue;
        }
        if (strcmp(arg, "--select") == 0) {
            i++;
            if (i >= argc) {
                break;
            }
            char *end = NULL;
            long val = strtol(argv[i], &end, 10);
            if (end && *end == '\0' && val >= 0) {
                push_select(result, (int)val);
            }
            continue;
        }
        if (strcmp(arg, "--range") == 0) {
            i++;
            if (i >= argc) {
                break;
            }
            Range r;
            if (parse_range(argv[i], &r)) {
                push_range(result, r);
            }
            continue;
        }
        if (strcmp(arg, "--dictionary") == 0) {
            i++;
            if (i >= argc) {
                break;
            }
            char *spec = wl_strdup(argv[i]);
            char *colon = strchr(spec, ':');
            if (colon && colon != spec && colon[1] != '\0') {
                *colon = '\0';
                apply_dictionary_path(result, spec, colon + 1);
            }
            free(spec);
            continue;
        }
        if (strcmp(arg, "--template") == 0) {
            i++;
            if (i >= argc) {
                fprintf(stderr, "Missing path for --template\n");
                exit(1);
            }
            apply_template(result, argv[i]);
            continue;
        }
        strlist_push(&result->patterns, arg);
    }
}

static char *load_help_text(const char *argv0) {
    char near_bin[4096];
    char near_docs[4096];
    near_bin[0] = '\0';
    near_docs[0] = '\0';

    if (argv0) {
        const char *slash = strrchr(argv0, '/');
        if (slash) {
            size_t dir_len = (size_t)(slash - argv0);
            if (dir_len + 16 < sizeof(near_bin)) {
                memcpy(near_bin, argv0, dir_len);
                near_bin[dir_len] = '\0';
                snprintf(near_bin + dir_len, sizeof(near_bin) - dir_len, "/help.txt");
                snprintf(near_docs, sizeof(near_docs), "%.*s/../docs/help.txt", (int)dir_len, argv0);
            }
        }
    }

    const char *candidates[] = {
        near_bin[0] ? near_bin : NULL,
        near_docs[0] ? near_docs : NULL,
        "docs/help.txt",
    };

    for (size_t i = 0; i < sizeof(candidates) / sizeof(candidates[0]); i++) {
        if (!candidates[i]) {
            continue;
        }
        char *content = read_file(candidates[i]);
        if (content) {
            return content;
        }
    }
    return wl_strdup("wildling - pattern based string generator\n\nHelp text unavailable.\n");
}

static char *format_list(char **values, size_t n) {
    if (n == 0) {
        return wl_strdup("");
    }
    size_t total = 2;
    for (size_t i = 0; i < n; i++) {
        total += strlen(values[i]) + 1;
    }
    char *out = malloc(total);
    if (!out) {
        return NULL;
    }
    out[0] = ' ';
    out[1] = '\0';
    for (size_t i = 0; i < n; i++) {
        if (i > 0) {
            strcat(out, " ");
        }
        strcat(out, values[i]);
    }
    return out;
}

static void print_check(const CliArgs *args, const Wildling *w) {
    char *patterns = format_list(args->patterns.items, args->patterns.len);
    char **dict_names = malloc(args->dictionaries.len * sizeof(char *));
    for (size_t i = 0; i < args->dictionaries.len; i++) {
        dict_names[i] = args->dictionaries.items[i].name;
    }
    char *dicts = format_list(dict_names, args->dictionaries.len);
    free(dict_names);

    char **selects = malloc(args->selects_len * sizeof(char *));
    for (size_t i = 0; i < args->selects_len; i++) {
        selects[i] = malloc(32);
        snprintf(selects[i], 32, "%d", args->selects[i]);
    }
    char *select_s = format_list(selects, args->selects_len);
    for (size_t i = 0; i < args->selects_len; i++) {
        free(selects[i]);
    }
    free(selects);

    char **ranges = malloc(args->ranges_len * sizeof(char *));
    for (size_t i = 0; i < args->ranges_len; i++) {
        ranges[i] = malloc(64);
        snprintf(ranges[i], 64, "%d-%d", args->ranges[i].start, args->ranges[i].end);
    }
    char *range_s = format_list(ranges, args->ranges_len);
    for (size_t i = 0; i < args->ranges_len; i++) {
        free(ranges[i]);
    }
    free(ranges);

    printf("patterns:%s\n", patterns ? patterns : "");
    printf("dictionaries:%s\n", dicts ? dicts : "");
    printf("select:%s\n", select_s ? select_s : "");
    printf("range:%s\n", range_s ? range_s : "");
    printf("total: %d", wildling_count(w));

    size_t gen_len = 0;
    const Generator *gens = wildling_generators(w, &gen_len);
    for (size_t i = 0; i < gen_len; i++) {
        printf("\ngenerator: %s %d", gens[i].source, generator_count(&gens[i]));
    }
    printf("\n");

    free(patterns);
    free(dicts);
    free(select_s);
    free(range_s);
}

int main(int argc, char **argv) {
    CliArgs args;
    parse_args(argc, argv, &args);

    if (args.help) {
        char *help = load_help_text(argv[0]);
        rtrim_inplace(help);
        printf("%s\n", help);
        free(help);
        cliargs_free(&args);
        return 0;
    }

    if (args.version) {
        printf("wildling %s\n", WILDLING_VERSION);
        cliargs_free(&args);
        return 0;
    }

    if (args.patterns.len == 0) {
        fprintf(stderr, "No pattern provided. Use --help for usage information.\n");
        cliargs_free(&args);
        return 1;
    }

    Wildling w;
    if (wildling_init(&w, args.patterns.items, args.patterns.len, &args.dictionaries) != 0) {
        fprintf(stderr, "Failed to initialize wildling\n");
        cliargs_free(&args);
        return 1;
    }

    if (args.check) {
        print_check(&args, &w);
        wildling_free(&w);
        cliargs_free(&args);
        return 0;
    }

    if (args.selects_len > 0 || args.ranges_len > 0) {
        int oor = 0;
        for (size_t i = 0; i < args.selects_len; i++) {
            int index = args.selects[i];
            char *value = wildling_get(&w, index);
            if (value) {
                printf("%s\n", value);
                free(value);
            } else {
                fprintf(stderr, "out of range: %d\n", index);
                oor = 1;
            }
        }
        for (size_t i = 0; i < args.ranges_len; i++) {
            for (int index = args.ranges[i].start; index <= args.ranges[i].end; index++) {
                char *value = wildling_get(&w, index);
                if (value) {
                    printf("%s\n", value);
                    free(value);
                } else {
                    fprintf(stderr, "out of range: %d\n", index);
                    oor = 1;
                }
            }
        }
        wildling_free(&w);
        cliargs_free(&args);
        return oor;
    }

    char *value = wildling_next(&w);
    while (value) {
        printf("%s\n", value);
        free(value);
        value = wildling_next(&w);
    }

    wildling_free(&w);
    cliargs_free(&args);
    return 0;
}
