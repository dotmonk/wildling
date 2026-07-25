#!/bin/sh
# Post-release consumer smoke for lua (git/GitHub + registry as documented).
set -eu

LANG_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$LANG_DIR/.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/scripts/post-release-smoke-lib.sh"
post_release_smoke_init

SMOKE_FAIL=0

smoke_lua() {
    channel lua git smoke_lua_git
    channel lua registry smoke_lua_registry
}

smoke_lua_git() {
    # Rockspecs through 2.0.6 used paths relative to lua/; newer ones use repo-root paths.
    _wd="$(workdir lua-git)"
    clone_tag "${_wd}/repo"
    run_docker_root "python:3.13-alpine" "${_wd}" '
set -eu
apk add --no-cache lua5.4 lua5.4-dev luarocks5.4 gcc musl-dev git >/dev/null
cd repo
ROCKSPEC="lua/wildling-'"${VERSION}"'-1.rockspec"
if grep -q "lua/lib/wildling" "$ROCKSPEC"; then
  luarocks-5.4 make "$ROCKSPEC" --tree=/tmp/rocks
else
  cd lua
  luarocks-5.4 make "wildling-'"${VERSION}"'-1.rockspec" --tree=/tmp/rocks
fi
eval "$(luarocks-5.4 path --tree=/tmp/rocks --bin)"
lua5.4 -e "
local wildling = require(\"wildling\")
local w = wildling.create({ \"ab\" })
assert(w:count() == 1)
assert(w:get(0) == \"ab\")
"
wildling --version | grep -F "'"${VERSION}"'"
[ "$(wildling ab)" = ab ]
'
}

smoke_lua_registry() {
    # Try a normal install first (works after rockspec fix is published).
    # Fall back to download+unpack+make for 2.0.6-era rocks with bad source.dir.
    _wd="$(workdir lua-registry)"
    run_docker_root "python:3.13-alpine" "${_wd}" '
set -eu
apk add --no-cache lua5.4 lua5.4-dev luarocks5.4 gcc musl-dev git unzip curl >/dev/null
set +e
luarocks-5.4 install wildling "'"${VERSION}"'-1" --tree=/tmp/rocks
status=$?
set -e
if [ "$status" -ne 0 ]; then
  mkdir -p dl && cd dl
  luarocks-5.4 download wildling "'"${VERSION}"'-1" --source
  mkdir unpack && cd unpack
  unzip -q ../wildling-'"${VERSION}"'-1.src.rock
  cd wildling/lua
  luarocks-5.4 make "wildling-'"${VERSION}"'-1.rockspec" --tree=/tmp/rocks
fi
eval "$(luarocks-5.4 path --tree=/tmp/rocks --bin)"
lua5.4 -e "
local wildling = require(\"wildling\")
local w = wildling.create({ \"ab\" })
assert(w:count() == 1)
assert(w:get(0) == \"ab\")
"
wildling --version | grep -F "'"${VERSION}"'"
[ "$(wildling ab)" = ab ]
'
}

smoke_lua

if [ "$SMOKE_FAIL" -ne 0 ]; then
    echo "Post-release smoke failed for lua." >&2
    exit 1
fi
