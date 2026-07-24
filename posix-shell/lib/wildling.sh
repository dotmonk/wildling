#!/bin/sh
# wildling library and CLI helpers (POSIX sh + awk)

WILDLING_VERSION="2.0.4"

_wildling_libdir() {
    if [ -n "$WILDLING_LIBDIR" ]; then
        printf '%s\n' "$WILDLING_LIBDIR"
        return
    fi
    if [ -n "$0" ] && [ -f "$0" ]; then
        _dir="$(cd "$(dirname "$0")" && pwd)"
        if [ -d "$_dir/../lib" ]; then
            printf '%s\n' "$(cd "$_dir/../lib" && pwd)"
            return
        fi
    fi
    printf '%s\n' "/dev/null"
}

wildling_load_help() {
    _lib="$(_wildling_libdir)"
    _root="$(cd "$_lib/.." && pwd)"
    if [ -f "$_root/help.txt" ]; then
        cat "$_root/help.txt"
        return
    fi
    if [ -f "$_root/../docs/help.txt" ]; then
        cat "$_root/../docs/help.txt"
        return
    fi
    printf '%s\n' "wildling - pattern based string generator" "" "Help text unavailable."
}

wildling_parse_range() {
    _value="$1"
    _start="${_value%%-*}"
    _end="${_value#*-}"
    case "$_start" in
        ''|*[!0-9]*) return 1 ;;
    esac
    case "$_end" in
        ''|*[!0-9]*) return 1 ;;
    esac
    if [ "$_start" -gt "$_end" ]; then
        return 1
    fi
    printf '%s-%s\n' "$_start" "$_end"
}

wildling_load_dictionary_file() {
    _path="$1"
    if [ ! -f "$_path" ]; then
        return 1
    fi
    # Include CR so CRLF dictionary files match LF-trimmed ports.
    _wl_cr=$(printf '\r')
    _wl_tab=$(printf '\t')
    while IFS= read -r _line || [ -n "$_line" ]; do
        _trimmed="$_line"
        while [ -n "$_trimmed" ]; do
            _c="${_trimmed%"${_trimmed#?}"}"
            case "$_c" in
                ''|' '|"$_wl_tab"|"$_wl_cr") _trimmed="${_trimmed#?}" ;;
                *) break ;;
            esac
        done
        while [ -n "$_trimmed" ]; do
            _c="${_trimmed#"${_trimmed%?}"}"
            case "$_c" in
                ''|' '|"$_wl_tab"|"$_wl_cr") _trimmed="${_trimmed%?}" ;;
                *) break ;;
            esac
        done
        if [ -n "$_trimmed" ]; then
            printf '%s\n' "$_trimmed"
        fi
    done < "$_path"
}

_wildling_data_file=""
_wildling_patterns=""
_wildling_dict_names=""
_wildling_selects=""
_wildling_ranges=""
_wildling_check=0

_wildling_cleanup() {
    if [ -n "$_wildling_data_file" ] && [ -f "$_wildling_data_file" ]; then
        rm -f "$_wildling_data_file"
    fi
}

_wildling_init_data() {
    _wildling_data_file="$(mktemp "${TMPDIR:-/tmp}/wildling_data.XXXXXX")"
    trap _wildling_cleanup EXIT INT TERM
}

_wildling_add_pattern() {
    _pattern="$1"
    _wildling_patterns="${_wildling_patterns}${_wildling_patterns:+	}${_pattern}"
    printf 'pattern\t%s\n' "$_pattern" >> "$_wildling_data_file"
}

_wildling_add_dict_word() {
    _name="$1"
    _word="$2"
    printf 'dict\t%s\t%s\n' "$_name" "$_word" >> "$_wildling_data_file"
}

_wildling_track_dict_name() {
    _name="$1"
    _found=0
    for _existing in $_wildling_dict_names; do
        if [ "$_existing" = "$_name" ]; then
            _found=1
            break
        fi
    done
    if [ "$_found" -eq 0 ]; then
        _wildling_dict_names="${_wildling_dict_names}${_wildling_dict_names:+ }${_name}"
    fi
}

_wildling_apply_dictionary_path() {
    _name="$1"
    _path="$2"
    if [ ! -f "$_path" ]; then
        return
    fi
    _wildling_track_dict_name "$_name"
    while IFS= read -r _word; do
        _wildling_add_dict_word "$_name" "$_word"
    done <<EOF_DICT
$(wildling_load_dictionary_file "$_path")
EOF_DICT
}

_wildling_apply_template() {
    _path="$1"
    _lib="$(_wildling_libdir)"
    if [ ! -f "$_path" ]; then
        printf 'Template file not found: %s\n' "$_path" >&2
        exit 1
    fi
    _tmpl_file="$(mktemp "${TMPDIR:-/tmp}/wildling_tmpl.XXXXXX")"
    if ! awk -f "$_lib/template.awk" "$_path" > "$_tmpl_file"; then
        rm -f "$_tmpl_file"
        printf 'Invalid JSON template: %s\n' "$_path" >&2
        exit 1
    fi
    _current_dict=""
    while IFS= read -r _line; do
        _cmd="${_line%% *}"
        _rest="${_line#* }"
        case "$_cmd" in
            check)
                if [ "$_rest" = "1" ]; then
                    _wildling_check=1
                fi
                ;;
            select)
                if [ -n "$_rest" ]; then
                    case "$_rest" in
                        *[!0-9]*) ;;
                        *)
                            _wildling_selects="${_wildling_selects}${_wildling_selects:+ }${_rest}"
                            ;;
                    esac
                fi
                ;;
            range)
                if wildling_parse_range "$_rest" >/dev/null 2>&1; then
                    _wildling_ranges="${_wildling_ranges}${_wildling_ranges:+ }${_rest}"
                fi
                ;;
            dict_name)
                _current_dict="$_rest"
                _wildling_track_dict_name "$_current_dict"
                ;;
            dict_word)
                _dname="${_rest%% *}"
                _dword="${_rest#* }"
                _wildling_add_dict_word "$_dname" "$_dword"
                ;;
            dict_path)
                _dname="${_rest%% *}"
                _dpath="${_rest#* }"
                _wildling_apply_dictionary_path "$_dname" "$_dpath"
                ;;
            pattern)
                _wildling_add_pattern "$_rest"
                ;;
        esac
    done < "$_tmpl_file"
    rm -f "$_tmpl_file"
}

_wildling_parse_args() {
    _wildling_init_data
    while [ $# -gt 0 ]; do
        _arg="$1"
        shift
        case "$_arg" in
            --help|-h)
                _WILDLING_HELP=1
                ;;
            --version|-v)
                _WILDLING_VERSION=1
                ;;
            --check)
                _wildling_check=1
                ;;
            --select)
                if [ $# -eq 0 ]; then
                    break
                fi
                _val="$1"
                shift
                case "$_val" in
                    *[!0-9]*) ;;
                    *)
                        _wildling_selects="${_wildling_selects}${_wildling_selects:+ }${_val}"
                        ;;
                esac
                ;;
            --range)
                if [ $# -eq 0 ]; then
                    break
                fi
                _val="$1"
                shift
                if wildling_parse_range "$_val" >/dev/null 2>&1; then
                    _wildling_ranges="${_wildling_ranges}${_wildling_ranges:+ }${_val}"
                fi
                ;;
            --dictionary)
                if [ $# -eq 0 ]; then
                    break
                fi
                _spec="$1"
                shift
                _dname="${_spec%%:*}"
                _dpath="${_spec#*:}"
                if [ "$_dname" != "$_spec" ] && [ -n "$_dname" ] && [ -n "$_dpath" ]; then
                    _wildling_apply_dictionary_path "$_dname" "$_dpath"
                fi
                ;;
            --template)
                if [ $# -eq 0 ]; then
                    printf 'Missing path for --template\n' >&2
                    exit 1
                fi
                _wildling_apply_template "$1"
                shift
                ;;
            *)
                _wildling_add_pattern "$_arg"
                ;;
        esac
    done
}

_wildling_run_engine() {
    _lib="$(_wildling_libdir)"
    _mode="generate"
    if [ "$_wildling_check" -eq 1 ]; then
        _mode="check"
    fi
    awk -f "$_lib/wildling.awk" \
        -v mode="$_mode" \
        -v data_file="$_wildling_data_file" \
        -v select_list="$_wildling_selects" \
        -v range_list="$_wildling_ranges"
    return $?
}

wildling_cli_main() {
    _WILDLING_HELP=0
    _WILDLING_VERSION=0
    _wildling_patterns=""
    _wildling_dict_names=""
    _wildling_selects=""
    _wildling_ranges=""
    _wildling_check=0

    _wildling_parse_args "$@"

    if [ "$_WILDLING_HELP" -eq 1 ]; then
        wildling_load_help | sed '$s/[[:space:]]*$//'
        exit 0
    fi

    if [ "$_WILDLING_VERSION" -eq 1 ]; then
        printf 'wildling %s\n' "$WILDLING_VERSION"
        exit 0
    fi

    if [ -z "$_wildling_patterns" ]; then
        printf 'No pattern provided. Use --help for usage information.\n' >&2
        exit 1
    fi

    _wildling_run_engine
    exit $?
}
