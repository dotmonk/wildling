#!/bin/sh

set -ef

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_DIR"

LANGUAGES_FILE="$PROJECT_DIR/languages.txt"

usage() {
    echo "Usage: $0 [language ...]"
    echo "  Install wildling as documented (git/GitHub + registry) and exercise"
    echo "  the library and CLI for one or more languages."
    echo "  With no arguments, smokes every language in languages.txt."
    echo
    echo "Env:"
    echo "  WILDLING_SMOKE_TAG       Release tag (default: latest release, or v\$VERSION)"
    echo "  WILDLING_SMOKE_WORKDIR   Base temp dir (default: mktemp -d)"
    echo "  WILDLING_SMOKE_REPO      GitHub repo URL (default: https://github.com/dotmonk/wildling.git)"
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
    usage
    exit 0
fi

if [ "$#" -gt 0 ]; then
    SELECTED="$*"
else
    SELECTED="$(grep -v '^[[:space:]]*#' "$LANGUAGES_FILE" | grep -v '^[[:space:]]*$')"
fi

export WILDLING_SMOKE_LANGUAGES="$SELECTED"
chmod +x "$PROJECT_DIR/scripts/post-release-smoke.sh"
exec "$PROJECT_DIR/scripts/post-release-smoke.sh"
