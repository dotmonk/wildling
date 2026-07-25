#!/bin/sh
# Post-release consumer smoke for fsharp (git/GitHub + registry as documented).
set -eu

LANG_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$LANG_DIR/.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/scripts/post-release-smoke-lib.sh"
post_release_smoke_init

SMOKE_FAIL=0

smoke_fsharp() {
    channel fsharp git smoke_fsharp_git
    channel fsharp registry smoke_fsharp_registry
}

smoke_fsharp_git() {
    smoke_clone_build_cli fsharp
}

smoke_fsharp_registry() {
    _wd="$(workdir fsharp-registry)"
    run_docker "mcr.microsoft.com/dotnet/sdk:8.0-alpine" "${_wd}" '
set -eu
export DOTNET_CLI_HOME=/tmp
dotnet tool install -g DotMonk.Wildling.FSharp --version "'"${VERSION}"'"
export PATH="$PATH:/tmp/.dotnet/tools"
wildling-fs --version | grep -F "'"${VERSION}"'"
[ "$(wildling-fs ab)" = ab ]
'
}

smoke_fsharp

if [ "$SMOKE_FAIL" -ne 0 ]; then
    echo "Post-release smoke failed for fsharp." >&2
    exit 1
fi
