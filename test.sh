#!/bin/sh

set -ef

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_DIR"

LANGUAGES_FILE="$PROJECT_DIR/languages.txt"

usage() {
    echo "Usage: $0 [language ...]"
    echo "Test one or more languages. With no arguments, tests all listed in languages.txt."
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
    usage
    exit 0
fi

if [ "$#" -gt 0 ]; then
    LANGUAGES="$*"
else
    LANGUAGES="$(grep -v '^[[:space:]]*#' "$LANGUAGES_FILE" | grep -v '^[[:space:]]*$')"
fi

TEST_DIRS=$(ls tests/)

for language in $LANGUAGES; do
    cli="$language/bin/wildling"
    if [ ! -x "$cli" ]; then
        echo "Unknown or untested language: $language" >&2
        echo "Expected executable: $cli" >&2
        exit 1
    fi

    echo "$language"
    for test_dir in $TEST_DIRS; do
        echo "Testing $language for $test_dir using command: $cli $(cat "tests/$test_dir/arguments.txt")"
        # shellcheck disable=SC2046
        if ! "$cli" $(cat "tests/$test_dir/arguments.txt") | cmp - "tests/$test_dir/expected.txt"; then
            echo "Test failed for $language in $test_dir"
            echo
            echo "Output:"
            "$cli" $(cat "tests/$test_dir/arguments.txt")
            echo
            echo "Expected:"
            cat "tests/$test_dir/expected.txt"
            echo
            echo "Diff:"
            "$cli" $(cat "tests/$test_dir/arguments.txt") | diff - "tests/$test_dir/expected.txt"
            exit 1
        fi
    done
done

echo
echo "All tests passed!"
