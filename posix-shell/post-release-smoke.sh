#!/bin/sh
# Post-release consumer smoke for posix-shell (git/GitHub + registry as documented).
set -eu

LANG_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$LANG_DIR/.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/scripts/post-release-smoke-lib.sh"
post_release_smoke_init

SMOKE_FAIL=0

smoke_posix_shell() {
    channel posix-shell git smoke_posix_shell_git
}

smoke_posix_shell_git() {
    smoke_clone_build_cli posix-shell
    _wd="${SMOKE_ROOT}/posix-shell-git"
    # Library: source lib and run a tiny shell check via the CLI already covers engine;
    # also verify lib file exists and is sourcable.
    sh -c '
set -eu
cd "'"${_wd}"'/repo/posix-shell"
. ./lib/wildling.sh
type _wildling_parse_args >/dev/null
type _wildling_run_engine >/dev/null
'
}

smoke_posix_shell

if [ "$SMOKE_FAIL" -ne 0 ]; then
    echo "Post-release smoke failed for posix-shell." >&2
    exit 1
fi
