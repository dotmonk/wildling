#!/bin/sh
# Post-release consumer smoke for zig (git/GitHub + registry as documented).
set -eu

LANG_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$LANG_DIR/.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/scripts/post-release-smoke-lib.sh"
post_release_smoke_init

SMOKE_FAIL=0

smoke_zig() {
    channel zig git smoke_zig_git
}

smoke_zig_git() {
    smoke_clone_build_cli zig
}

smoke_zig

if [ "$SMOKE_FAIL" -ne 0 ]; then
    echo "Post-release smoke failed for zig." >&2
    exit 1
fi
