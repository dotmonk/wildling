#!/bin/sh
# Post-release consumer smoke for visualbasic (git/GitHub + registry as documented).
set -eu

LANG_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$LANG_DIR/.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/scripts/post-release-smoke-lib.sh"
post_release_smoke_init

SMOKE_FAIL=0

smoke_visualbasic() {
    channel visualbasic git smoke_visualbasic_git
    channel visualbasic registry smoke_visualbasic_registry
}

smoke_visualbasic_git() {
    smoke_clone_build_cli visualbasic
}

smoke_visualbasic_registry() {
    _wd="$(workdir visualbasic-registry)"
    run_dotnet_docker "mcr.microsoft.com/dotnet/sdk:8.0-alpine" "${_wd}" '
set -eu
export DOTNET_CLI_HOME=/tmp
dotnet tool install -g DotMonk.Wildling.VisualBasic --version "'"${VERSION}"'"
export PATH="$PATH:/tmp/.dotnet/tools"
wildling-vb --version | grep -F "'"${VERSION}"'"
[ "$(wildling-vb ab)" = ab ]
'
}

smoke_visualbasic

if [ "$SMOKE_FAIL" -ne 0 ]; then
    echo "Post-release smoke failed for visualbasic." >&2
    exit 1
fi
