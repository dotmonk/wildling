# Template JSON parser for wildling (POSIX awk).
# Reads a template file and prints directive lines:
#   pattern <value>
#   dict_name <name>
#   dict_word <name> <word>
#   dict_path <name> <path>
#   select <n>
#   range <start-end>
#   check <0|1>

function skip_ws(text, pos,    c) {
    while (pos <= length(text)) {
        c = substr(text, pos, 1)
        if (c != " " && c != "\t" && c != "\n" && c != "\r") {
            break
        }
        pos++
    }
    return pos
}

function parse_string(text, pos,    buf, c, esc) {
    pos = skip_ws(text, pos)
    if (substr(text, pos, 1) != "\"") {
        return 0
    }
    pos++
    buf = ""
    while (pos <= length(text)) {
        c = substr(text, pos, 1)
        pos++
        if (c == "\"") {
            return pos SUBSEP buf
        }
        if (c == "\\") {
            esc = substr(text, pos, 1)
            pos++
            if (esc == "n") {
                c = "\n"
            } else if (esc == "t") {
                c = "\t"
            } else if (esc == "r") {
                c = "\r"
            } else {
                c = esc
            }
        }
        buf = buf c
    }
    return 0
}

function parse_number_token(text, pos,    start) {
    pos = skip_ws(text, pos)
    start = pos
    if (substr(text, pos, 1) == "-") {
        pos++
    }
    while (pos <= length(text) && substr(text, pos, 1) ~ /[0-9]/) {
        pos++
    }
    if (pos == start || (pos == start + 1 && substr(text, start, 1) == "-")) {
        return 0
    }
    return pos SUBSEP substr(text, start, pos - start)
}

function parse_bool(text, pos,    c) {
    pos = skip_ws(text, pos)
    if (substr(text, pos, 4) == "true") {
        return pos + 4 SUBSEP "1"
    }
    if (substr(text, pos, 5) == "false") {
        return pos + 5 SUBSEP "0"
    }
    return 0
}

function parse_string_array(text, pos,    c, result, item, n) {
    pos = skip_ws(text, pos)
    if (substr(text, pos, 1) != "[") {
        return 0
    }
    pos++
    n = 0
    while (1) {
        pos = skip_ws(text, pos)
        c = substr(text, pos, 1)
        if (c == "]") {
            return pos + 1 SUBSEP n
        }
        result = parse_string(text, pos)
        if (!result) {
            return 0
        }
        split(result, parts, SUBSEP)
        pos = parts[1]
        n++
        tmpl_strings[n] = parts[2]
        pos = skip_ws(text, pos)
        c = substr(text, pos, 1)
        if (c == "]") {
            return pos + 1 SUBSEP n
        }
        if (c != ",") {
            return 0
        }
        pos++
    }
}

function parse_number_array(text, pos,    c, result, n, parts) {
    pos = skip_ws(text, pos)
    if (substr(text, pos, 1) != "[") {
        return 0
    }
    pos++
    n = 0
    while (1) {
        pos = skip_ws(text, pos)
        c = substr(text, pos, 1)
        if (c == "]") {
            return pos + 1 SUBSEP n
        }
        if (c == "\"") {
            result = parse_string(text, pos)
            if (!result) {
                return 0
            }
            split(result, parts, SUBSEP)
            pos = parts[1]
            n++
            tmpl_numbers[n] = parts[2] + 0
        } else {
            result = parse_number_token(text, pos)
            if (!result) {
                return 0
            }
            split(result, parts, SUBSEP)
            pos = parts[1]
            n++
            tmpl_numbers[n] = parts[2] + 0
        }
        pos = skip_ws(text, pos)
        c = substr(text, pos, 1)
        if (c == "]") {
            return pos + 1 SUBSEP n
        }
        if (c != ",") {
            return 0
        }
        pos++
    }
}

function parse_dict_value(text, pos, dict_name,    c, result, parts, n, i) {
    pos = skip_ws(text, pos)
    c = substr(text, pos, 1)
    if (c == "[") {
        result = parse_string_array(text, pos)
        if (!result) {
            return 0
        }
        split(result, parts, SUBSEP)
        pos = parts[1]
        n = parts[2]
        print "dict_name", dict_name
        for (i = 1; i <= n; i++) {
            print "dict_word", dict_name, tmpl_strings[i]
        }
        return pos
    }
    if (c == "\"") {
        result = parse_string(text, pos)
        if (!result) {
            return 0
        }
        split(result, parts, SUBSEP)
        print "dict_name", dict_name
        print "dict_path", dict_name, parts[2]
        return parts[1]
    }
    return 0
}

function parse_dictionaries(text, pos,    c, result, parts, key_parts, key) {
    pos = skip_ws(text, pos)
    if (substr(text, pos, 1) != "{") {
        return 0
    }
    pos++
    while (1) {
        pos = skip_ws(text, pos)
        c = substr(text, pos, 1)
        if (c == "}") {
            return pos + 1
        }
        result = parse_string(text, pos)
        if (!result) {
            return 0
        }
        split(result, key_parts, SUBSEP)
        pos = key_parts[1]
        key = key_parts[2]
        pos = skip_ws(text, pos)
        if (substr(text, pos, 1) != ":") {
            return 0
        }
        pos++
        pos = parse_dict_value(text, pos, key)
        if (!pos) {
            return 0
        }
        pos = skip_ws(text, pos)
        c = substr(text, pos, 1)
        if (c == "}") {
            return pos + 1
        }
        if (c != ",") {
            return 0
        }
        pos++
    }
}

function find_key(text, key,    re, pos, c) {
    re = "\"" key "\"[[:space:]]*:"
    if (!match(text, re)) {
        return 0
    }
    return RSTART + RLENGTH
}

BEGIN {
    if (ARGC < 2) {
        exit 1
    }
    text = ""
    while ((getline line < ARGV[1]) > 0) {
        text = text line "\n"
    }
    close(ARGV[1])

    pos = find_key(text, "check")
    if (pos) {
        result = parse_bool(text, pos)
        if (result) {
            split(result, parts, SUBSEP)
            print "check", parts[2]
        }
    }

    pos = find_key(text, "select")
    if (pos) {
        result = parse_number_array(text, pos)
        if (result) {
            split(result, parts, SUBSEP)
            n = parts[2]
            for (i = 1; i <= n; i++) {
                if (tmpl_numbers[i] >= 0) {
                    print "select", tmpl_numbers[i]
                }
            }
        }
    }

    pos = find_key(text, "range")
    if (pos) {
        result = parse_string_array(text, pos)
        if (result) {
            split(result, parts, SUBSEP)
            n = parts[2]
            for (i = 1; i <= n; i++) {
                print "range", tmpl_strings[i]
            }
        }
    }

    pos = find_key(text, "dictionaries")
    if (pos) {
        parse_dictionaries(text, pos)
    }

    pos = find_key(text, "patterns")
    if (pos) {
        result = parse_string_array(text, pos)
        if (result) {
            split(result, parts, SUBSEP)
            n = parts[2]
            for (i = 1; i <= n; i++) {
                print "pattern", tmpl_strings[i]
            }
        }
    }
}
