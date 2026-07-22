#!/bin/sh
# Mirror php/ to dotmonk/wildling-php for Packagist (composer.json at mirror root).
#
# Usage:
#   PHP_MIRROR_TOKEN=ghp_... ./scripts/mirror-php-packagist.sh v2.0.0
set -eu

TAG="${1:-}"
if [ -z "$TAG" ]; then
    echo "Usage: $0 <tag>   e.g. v2.0.0" >&2
    exit 1
fi

. "$(dirname "$0")/mirror-ecosystem-lib.sh"
ROOT="$(mirror_ecosystem_root)"
MIRROR_REPO="${PHP_MIRROR_REPO:-dotmonk/wildling-php}"
TOKEN="${PHP_MIRROR_TOKEN:-}"

if [ ! -f "$ROOT/php/composer.json" ]; then
    echo "Missing $ROOT/php/composer.json" >&2
    exit 1
fi

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

rsync -a \
    --exclude 'dist' \
    --exclude 'help.txt' \
    "$ROOT/php/" "$WORKDIR/"

if [ -f "$ROOT/docs/help.txt" ]; then
    cp "$ROOT/docs/help.txt" "$WORKDIR/help.txt"
fi

mirror_ecosystem_copy_license "$WORKDIR"
mirror_ecosystem_push "$WORKDIR" "$TAG" "$TOKEN" "$MIRROR_REPO" "php"
