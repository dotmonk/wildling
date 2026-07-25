#!/bin/sh
# Post-release consumer smoke for pascal (git/GitHub + registry as documented).
set -eu

LANG_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$LANG_DIR/.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/scripts/post-release-smoke-lib.sh"
post_release_smoke_init

SMOKE_FAIL=0

smoke_pascal() {
    channel pascal git smoke_pascal_git
}

smoke_pascal_git() {
    smoke_clone_build_cli pascal
}

smoke_pascal

if [ "$SMOKE_FAIL" -ne 0 ]; then
    echo "Post-release smoke failed for pascal." >&2
    exit 1
fi
