#!/bin/sh
# Post-release consumer smoke for csharp (git/GitHub + registry as documented).
set -eu

LANG_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$LANG_DIR/.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/scripts/post-release-smoke-lib.sh"
post_release_smoke_init

SMOKE_FAIL=0

smoke_csharp() {
    channel csharp git smoke_csharp_git
    channel csharp registry smoke_csharp_registry
}

smoke_csharp_git() {
    smoke_clone_build_cli csharp
    _wd="${SMOKE_ROOT}/csharp-git"
    run_docker "mcr.microsoft.com/dotnet/sdk:8.0-alpine" "${_wd}/repo/csharp" '
set -eu
dotnet new console -n LibSmoke -o /tmp/LibSmoke --force
cd /tmp/LibSmoke
dotnet add reference /work/Wildling.csproj
cat > Program.cs <<EOF
using WildlingLib;
var w = Wildling.Create(new[] { "ab" });
if (w.Count() != 1) return 1;
if (!Equals(w.Get(0), "ab")) return 2;
return 0;
EOF
dotnet run -c Release
'
}

smoke_csharp_registry() {
    # Documented registry install is the global tool (PackAsTool); not a library PackageReference.
    _wd="$(workdir csharp-registry)"
    run_docker "mcr.microsoft.com/dotnet/sdk:8.0-alpine" "${_wd}" '
set -eu
export DOTNET_CLI_HOME=/tmp
dotnet tool install -g DotMonk.Wildling --version "'"${VERSION}"'"
export PATH="$PATH:/tmp/.dotnet/tools"
wildling --version | grep -F "'"${VERSION}"'"
[ "$(wildling ab)" = ab ]
wildling --check ab | grep -q "^total: 1$"
'
}

smoke_csharp

if [ "$SMOKE_FAIL" -ne 0 ]; then
    echo "Post-release smoke failed for csharp." >&2
    exit 1
fi
