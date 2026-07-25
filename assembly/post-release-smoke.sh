#!/bin/sh
# Post-release consumer smoke for assembly (git/GitHub + registry as documented).
set -eu

LANG_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$LANG_DIR/.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/scripts/post-release-smoke-lib.sh"
post_release_smoke_init

SMOKE_FAIL=0

smoke_assembly() {
    channel assembly git smoke_assembly_git
}

smoke_assembly_git() {
    # CLI only (no installable library documented)
    smoke_clone_build_cli assembly
}

smoke_assembly

if [ "$SMOKE_FAIL" -ne 0 ]; then
    echo "Post-release smoke failed for assembly." >&2
    exit 1
fi
