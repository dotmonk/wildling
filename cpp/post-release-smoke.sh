#!/bin/sh
# Post-release consumer smoke for cpp (git/GitHub + registry as documented).
set -eu

LANG_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$LANG_DIR/.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/scripts/post-release-smoke-lib.sh"
post_release_smoke_init

SMOKE_FAIL=0

smoke_cpp() {
    channel cpp git smoke_cpp_git
    channel cpp registry smoke_cpp_release_assets
}

smoke_cpp_git() {
    smoke_clone_build_cli cpp
}

smoke_cpp_release_assets() {
    _wd="$(workdir cpp-registry)"
    _asset="wildling-cpp-${VERSION}-linux-x86_64.tar.gz"
    run_docker_root "gcc:14-bookworm" "${_wd}" '
set -eu
apt-get update -qq
apt-get install -y -qq curl ca-certificates >/dev/null
curl -fsSL -o asset.tgz "https://github.com/dotmonk/wildling/releases/download/'"${TAG}"'/'"${_asset}"'"
mkdir -p out && tar -xzf asset.tgz -C out
CLI="$(find out -type f -name wildling | head -n1)"
"$CLI" --version | grep -F "'"${VERSION}"'"
[ "$("$CLI" ab)" = ab ]
'
}

smoke_cpp

if [ "$SMOKE_FAIL" -ne 0 ]; then
    echo "Post-release smoke failed for cpp." >&2
    exit 1
fi
