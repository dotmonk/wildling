#!/bin/sh

set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_DIR"

LANGUAGES_FILE="$PROJECT_DIR/languages.txt"

usage() {
    echo "Usage: $0 [language ...]"
    echo "Build one or more languages. With no arguments, builds all listed in languages.txt."
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

for language in $LANGUAGES; do
    build_script="$PROJECT_DIR/$language/build.sh"
    if [ ! -x "$build_script" ]; then
        echo "Unknown or unbuildable language: $language" >&2
        echo "Expected executable: $language/build.sh" >&2
        exit 1
    fi
    echo "Building $language"
    "$build_script"
done
