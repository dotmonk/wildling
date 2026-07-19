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
        out="$(mktemp)"
        err="$(mktemp)"
        set +e
        "$cli" $(cat "tests/$test_dir/arguments.txt") >"$out" 2>"$err"
        status=$?
        set -e

        expected_exit=0
        if [ -f "tests/$test_dir/expected.exit" ]; then
            expected_exit="$(tr -d '[:space:]' < "tests/$test_dir/expected.exit")"
        fi

        fail=0
        if [ "$status" -ne "$expected_exit" ]; then
            echo "Test failed for $language in $test_dir (exit $status, expected $expected_exit)"
            fail=1
        fi
        if ! cmp -s "$out" "tests/$test_dir/expected.txt"; then
            echo "Test failed for $language in $test_dir (stdout)"
            fail=1
        fi
        if [ -f "tests/$test_dir/expected.stderr" ]; then
            if ! cmp -s "$err" "tests/$test_dir/expected.stderr"; then
                echo "Test failed for $language in $test_dir (stderr)"
                fail=1
            fi
        elif [ -s "$err" ]; then
            # No expected.stderr file: stderr must be empty for the fixture.
            echo "Test failed for $language in $test_dir (unexpected stderr)"
            fail=1
        fi

        if [ "$fail" -ne 0 ]; then
            echo
            echo "Exit: $status (expected $expected_exit)"
            echo
            echo "Stdout:"
            cat "$out"
            echo
            echo "Expected stdout:"
            cat "tests/$test_dir/expected.txt"
            echo
            echo "Stderr:"
            cat "$err"
            if [ -f "tests/$test_dir/expected.stderr" ]; then
                echo
                echo "Expected stderr:"
                cat "tests/$test_dir/expected.stderr"
            fi
            echo
            echo "Stdout diff:"
            diff -u "tests/$test_dir/expected.txt" "$out" || true
            if [ -f "tests/$test_dir/expected.stderr" ]; then
                echo
                echo "Stderr diff:"
                diff -u "tests/$test_dir/expected.stderr" "$err" || true
            fi
            rm -f "$out" "$err"
            exit 1
        fi
        rm -f "$out" "$err"
    done
done

echo
echo "All tests passed!"
