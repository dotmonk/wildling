#!/bin/sh
# Post-release consumer smoke for javascript (git/GitHub + registry as documented).
set -eu

LANG_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$LANG_DIR/.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/scripts/post-release-smoke-lib.sh"
post_release_smoke_init

SMOKE_FAIL=0

smoke_javascript() {
    channel javascript git smoke_javascript_git
    channel javascript registry smoke_javascript_registry
}

smoke_javascript_git() {
    _wd="$(workdir javascript-git)"
    run_docker_root "node:24.10-alpine" "${_wd}" '
set -eu
apk add --no-cache git >/dev/null
export npm_config_cache=/tmp/.npm
git clone --branch "'"${TAG}"'" --depth 1 https://github.com/dotmonk/wildling.git repo
cd repo/javascript
npm ci --include=dev
npm run build
cd /work
mkdir -p app && cd app
npm init -y >/dev/null
npm install /work/repo/javascript
npx wildling --version | grep -F "'"${VERSION}"'"
[ "$(npx wildling ab)" = ab ]
node -e "
const createWildling = require(\"wildling\").default;
const w = createWildling({ patterns: [\"ab\"] });
if (w.count() !== 1) process.exit(1);
if (w.get(0) !== \"ab\") process.exit(1);
"
'
}

smoke_javascript_registry() {
    _wd="$(workdir javascript-registry)"
    run_docker "node:24.10-alpine" "${_wd}" '
set -eu
export npm_config_cache=/tmp/.npm
mkdir -p app && cd app
npm init -y >/dev/null
npm install wildling@'"${VERSION}"'
npx wildling --version | grep -F "'"${VERSION}"'"
[ "$(npx wildling ab)" = ab ]
node -e "
const createWildling = require(\"wildling\").default;
const w = createWildling({ patterns: [\"ab\"] });
if (w.count() !== 1) process.exit(1);
if (w.get(0) !== \"ab\") process.exit(1);
"
' -e npm_config_cache=/tmp/.npm
}

smoke_javascript

if [ "$SMOKE_FAIL" -ne 0 ]; then
    echo "Post-release smoke failed for javascript." >&2
    exit 1
fi
