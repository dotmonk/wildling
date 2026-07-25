#!/bin/sh
# Post-release consumer smoke for powershell (git/GitHub + registry as documented).
set -eu

LANG_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$LANG_DIR/.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/scripts/post-release-smoke-lib.sh"
post_release_smoke_init

SMOKE_FAIL=0

smoke_powershell() {
    channel powershell git smoke_powershell_git
    channel powershell registry smoke_powershell_registry
}

smoke_powershell_git() {
    smoke_clone_build_cli powershell
}

smoke_powershell_registry() {
    _wd="$(workdir powershell-registry)"
    run_docker "mcr.microsoft.com/powershell" "${_wd}" '
set -eu
pwsh -NoLogo -Command "
\$ErrorActionPreference = \"Stop\"
Install-Module Wildling -RequiredVersion '"${VERSION}"' -Force -Scope CurrentUser -AllowClobber
Import-Module Wildling
\$w = New-WildlingClient -Patterns @(\"ab\")
if (\$w.GetCount() -ne 1) { exit 1 }
if (\$w.Get(0) -ne \"ab\") { exit 2 }
"
'
}

smoke_powershell

if [ "$SMOKE_FAIL" -ne 0 ]; then
    echo "Post-release smoke failed for powershell." >&2
    exit 1
fi
