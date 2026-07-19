# wildling core engine (POSIX awk)

function is_special(c) {
    return index("#@$*&?!-%", c) > 0
}

function ipow(base, exponent,    r, i) {
    r = 1
    for (i = 0; i < exponent; i++) {
        r *= base
    }
    return r
}

function split_pattern(input, parts,    i, len, literal_start, c, token_end, close_pos, n) {
    delete parts
    n = 0
    len = length(input)
    i = 1
    literal_start = 1

    while (i <= len) {
        c = substr(input, i, 1)

        if (c == "\\" && i < len && is_special(substr(input, i + 1, 1))) {
            if (i > literal_start) {
                parts[++n] = substr(input, literal_start, i - literal_start)
            }
            parts[++n] = substr(input, i, 2)
            i += 2
            literal_start = i
            continue
        }

        if (is_special(c)) {
            token_end = i
            if (i < len && substr(input, i + 1, 1) == "{") {
                close_pos = index(substr(input, i + 2), "}")
                if (close_pos > 0) {
                    token_end = i + 1 + close_pos
                }
            }
            if (i > literal_start) {
                parts[++n] = substr(input, literal_start, i - literal_start)
            }
            parts[++n] = substr(input, i, token_end - i + 1)
            i = token_end + 1
            literal_start = i
            continue
        }

        i++
    }

    if (literal_start <= len) {
        parts[++n] = substr(input, literal_start)
    }
    return n
}

function parse_length_with_variants(part,    open_pos, close_pos, inner, dash, start_len, end_len) {
    start_len = 1
    end_len = 1
    open_pos = index(part, "{")
    if (open_pos > 0) {
        close_pos = index(substr(part, open_pos), "}")
        if (close_pos > 0) {
            inner = substr(part, open_pos + 1, close_pos - 2)
            dash = index(inner, "-")
            if (dash > 0) {
                start_len = substr(inner, 1, dash - 1) + 0
                end_len = substr(inner, dash + 1) + 0
            } else {
                start_len = inner + 0
                end_len = start_len
            }
        }
    }
    return start_len SUBSEP end_len
}

function parse_length_with_string(part, result,    open_pos, rest, i, close_quote, content, after_quote, stripped, dash) {
    delete result
    result["ok"] = 0
    open_pos = index(part, "{'")
    if (open_pos == 0) {
        return
    }
    rest = substr(part, open_pos + 2)
    close_quote = 0
    for (i = length(rest); i >= 1; i--) {
        if (substr(rest, i, 1) == "'") {
            close_quote = i
            break
        }
    }
    if (close_quote == 0) {
        return
    }
    content = substr(rest, 1, close_quote - 1)
    after_quote = substr(rest, close_quote + 1)
    result["start"] = 1
    result["end"] = 1
    if (substr(after_quote, 1, 1) == ",") {
        stripped = substr(after_quote, 2)
        sub(/}$/, "", stripped)
        dash = index(stripped, "-")
        if (dash > 0) {
            result["start"] = substr(stripped, 1, dash - 1) + 0
            result["end"] = substr(stripped, dash + 1) + 0
        } else {
            result["start"] = stripped + 0
            result["end"] = result["start"]
        }
    } else if (substr(after_quote, 1, 1) != "}") {
        return
    }
    result["ok"] = 1
    result["content"] = content
}

function chars_to_variants(alphabet, variants,    i, n) {
    delete variants
    n = 0
    for (i = 1; i <= length(alphabet); i++) {
        variants[++n] = substr(alphabet, i, 1)
    }
    return n
}

function split_words(work, variants,    pos, n, piece) {
    delete variants
    n = 0
    pos = 1
    while (pos <= length(work)) {
        if (pos < length(work) && substr(work, pos, 2) == "\\,") {
            pos += 2
        } else if (substr(work, pos, 1) == ",") {
            piece = substr(work, 1, pos - 1)
            gsub(/\\,/, ",", piece)
            variants[++n] = piece
            work = substr(work, pos + 1)
            pos = 1
        } else {
            pos++
        }
    }
    gsub(/\\,/, ",", work)
    variants[++n] = work
    return n
}

function dict_has(name,    i) {
    return (name in dict_count) && dict_count[name] > 0
}

function dict_words(name, variants,    i, n) {
    delete variants
    n = dict_count[name]
    for (i = 1; i <= n; i++) {
        variants[i] = dict_entry[name, i]
    }
    return n
}

function build_token(part, tok_id,    first, variants, n, parsed, p, pls, i) {
    delete token_variant[tok_id]
    token_start[tok_id] = 1
    token_end[tok_id] = 1
    token_src[tok_id] = part
    token_vcount[tok_id] = 0
    token_count[tok_id] = 1

    if (part == "") {
        token_variant[tok_id, 1] = ""
        token_vcount[tok_id] = 1
        return
    }

    first = substr(part, 1, 1)

    if (first == "#") {
        n = chars_to_variants("0123456789", variants)
        parsed = parse_length_with_variants(part)
        split(parsed, p, SUBSEP)
        token_start[tok_id] = p[1]
        token_end[tok_id] = p[2]
    } else if (first == "@") {
        n = chars_to_variants("abcdefghijklmnopqrstuvwxyz", variants)
        parsed = parse_length_with_variants(part)
        split(parsed, p, SUBSEP)
        token_start[tok_id] = p[1]
        token_end[tok_id] = p[2]
    } else if (first == "*") {
        n = chars_to_variants("abcdefghijklmnopqrstuvwxyz0123456789", variants)
        parsed = parse_length_with_variants(part)
        split(parsed, p, SUBSEP)
        token_start[tok_id] = p[1]
        token_end[tok_id] = p[2]
    } else if (first == "-") {
        n = chars_to_variants("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789", variants)
        parsed = parse_length_with_variants(part)
        split(parsed, p, SUBSEP)
        token_start[tok_id] = p[1]
        token_end[tok_id] = p[2]
    } else if (first == "!") {
        n = chars_to_variants("ABCDEFGHIJKLMNOPQRSTUVWXYZ", variants)
        parsed = parse_length_with_variants(part)
        split(parsed, p, SUBSEP)
        token_start[tok_id] = p[1]
        token_end[tok_id] = p[2]
    } else if (first == "?") {
        n = chars_to_variants("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789", variants)
        parsed = parse_length_with_variants(part)
        split(parsed, p, SUBSEP)
        token_start[tok_id] = p[1]
        token_end[tok_id] = p[2]
    } else if (first == "&") {
        n = chars_to_variants("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ", variants)
        parsed = parse_length_with_variants(part)
        split(parsed, p, SUBSEP)
        token_start[tok_id] = p[1]
        token_end[tok_id] = p[2]
    } else if (first == "%") {
        parse_length_with_string(part, pls)
        if (pls["ok"] != 1 || (pls["content"] != "" && !dict_has(pls["content"]))) {
            token_variant[tok_id, 1] = part
            token_vcount[tok_id] = 1
            recompute_token_count(tok_id)
            return
        }
        token_start[tok_id] = pls["start"]
        token_end[tok_id] = pls["end"]
        n = dict_words(pls["content"], variants)
    } else if (first == "$") {
        parse_length_with_string(part, pls)
        if (pls["ok"] != 1) {
            token_variant[tok_id, 1] = part
            token_vcount[tok_id] = 1
            recompute_token_count(tok_id)
            return
        }
        token_start[tok_id] = pls["start"]
        token_end[tok_id] = pls["end"]
        n = split_words(pls["content"], variants)
    } else if (first == "\\" && length(part) > 1 && is_special(substr(part, 2, 1))) {
        token_variant[tok_id, 1] = substr(part, 2)
        token_vcount[tok_id] = 1
        recompute_token_count(tok_id)
        return
    } else {
        token_variant[tok_id, 1] = part
        token_vcount[tok_id] = 1
        recompute_token_count(tok_id)
        return
    }

    for (i = 1; i <= n; i++) {
        token_variant[tok_id, i] = variants[i]
    }
    token_vcount[tok_id] = n
    recompute_token_count(tok_id)
}

function recompute_token_count(tok_id,    total, len, vc) {
    total = 0
    vc = token_vcount[tok_id]
    if (vc < 1) {
        token_count[tok_id] = 0
        return
    }
    for (len = token_start[tok_id]; len <= token_end[tok_id]; len++) {
        total += ipow(vc, len)
    }
    token_count[tok_id] = total
}

function token_get_value(tok_id, comb_index,    idx, len, offset_count, string_length, variant_index, out, i) {
    if (comb_index > token_count[tok_id] - 1 || comb_index < 0) {
        return ""
    }
    if (comb_index == 0 && token_start[tok_id] == 0) {
        return ""
    }

    idx = comb_index
    string_length = token_start[tok_id]
    for (len = token_start[tok_id]; len <= token_end[tok_id]; len++) {
        offset_count = ipow(token_vcount[tok_id], len)
        if (idx < offset_count) {
            string_length = len
            break
        }
        idx -= offset_count
    }

    out = ""
    for (i = 0; i < string_length; i++) {
        variant_index = idx % token_vcount[tok_id]
        idx = int(idx / token_vcount[tok_id])
        out = out token_variant[tok_id, variant_index + 1]
    }
    return out
}

function build_generator(pattern, gen_id,    parts, n, i, tok_base, tok_n) {
    gen_source[gen_id] = pattern
    n = split_pattern(pattern, parts)
    tok_n = 0
    tok_base = gen_id * 1000
    for (i = 1; i <= n; i++) {
        if (parts[i] == "") {
            continue
        }
        tok_n++
        build_token(parts[i], tok_base + tok_n)
    }
    gen_tok_count[gen_id] = tok_n
    gen_count[gen_id] = 1
    for (i = 1; i <= tok_n; i++) {
        gen_count[gen_id] *= token_count[tok_base + i]
    }
}

function generator_get_value(gen_id, comb_index,    tok_base, tok_n, idx, i, out) {
    if (comb_index > gen_count[gen_id] - 1 || comb_index < 0) {
        return ""
    }
    tok_n = gen_tok_count[gen_id]
    tok_base = gen_id * 1000
    idx = comb_index
    out = ""
    for (i = 1; i <= tok_n; i++) {
        out = out token_get_value(tok_base + i, idx % token_count[tok_base + i])
        idx = int(idx / token_count[tok_base + i])
    }
    return out
}

function wildling_get_value(comb_index,    i, seg, pattern_index) {
    if (comb_index > wildling_total - 1 || comb_index < 0) {
        return "__FALSE__"
    }
    seg = 0
    for (i = 1; i <= gen_n; i++) {
        pattern_index = comb_index - seg
        if (pattern_index < gen_count[i]) {
            return generator_get_value(i, pattern_index)
        }
        seg += gen_count[i]
    }
    return "__FALSE__"
}

function load_data_file(path,    line, n, parts) {
    while ((getline line < path) > 0) {
        n = split(line, parts, "\t")
        if (parts[1] == "pattern") {
            gen_n++
            build_generator(parts[2], gen_n)
        } else if (parts[1] == "dict") {
            name = parts[2]
            if (!(name in dict_count)) {
                dict_count[name] = 0
                dict_order[++dict_order_n] = name
            }
            dict_count[name]++
            dict_entry[name, dict_count[name]] = parts[3]
        }
    }
    close(path)

    wildling_total = 0
    for (i = 1; i <= gen_n; i++) {
        wildling_total += gen_count[i]
    }
}

BEGIN {
    gen_n = 0
    wildling_total = 0
    dict_order_n = 0

    if (data_file == "") {
        exit 1
    }
    load_data_file(data_file)

    if (mode == "check") {
        printf "patterns:"
        for (i = 1; i <= gen_n; i++) {
            printf " %s", gen_source[i]
        }
        print ""

        printf "dictionaries:"
        for (i = 1; i <= dict_order_n; i++) {
            printf " %s", dict_order[i]
        }
        print ""

        printf "select:"
        if (select_list != "") {
            n = split(select_list, sl, " ")
            for (i = 1; i <= n; i++) {
                printf " %s", sl[i]
            }
        }
        print ""

        printf "range:"
        if (range_list != "") {
            n = split(range_list, rl, " ")
            for (i = 1; i <= n; i++) {
                printf " %s", rl[i]
            }
        }
        print ""

        printf "total: %d", wildling_total
        for (i = 1; i <= gen_n; i++) {
            printf "\ngenerator: %s %d", gen_source[i], gen_count[i]
        }
        print ""
        exit 0
    }

    if (select_list != "" || range_list != "") {
        oor = 0
        if (select_list != "") {
            n = split(select_list, sl, " ")
            for (i = 1; i <= n; i++) {
                idx = sl[i] + 0
                val = wildling_get_value(idx)
                if (val == "__FALSE__") {
                    print "out of range: " idx > "/dev/stderr"
                    oor = 1
                } else {
                    print val
                }
            }
        }
        if (range_list != "") {
            n = split(range_list, rl, " ")
            for (i = 1; i <= n; i++) {
                split(rl[i], rp, "-")
                start = rp[1] + 0
                end = rp[2] + 0
                for (idx = start; idx <= end; idx++) {
                    val = wildling_get_value(idx)
                    if (val == "__FALSE__") {
                        print "out of range: " idx > "/dev/stderr"
                        oor = 1
                    } else {
                        print val
                    }
                }
            }
        }
        exit oor
    }

    for (idx = 0; idx < wildling_total; idx++) {
        print wildling_get_value(idx)
    }
}
