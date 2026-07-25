#!/bin/sh
# Post-release consumer smoke for python (git/GitHub + registry as documented).
set -eu

LANG_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$LANG_DIR/.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/scripts/post-release-smoke-lib.sh"
post_release_smoke_init

SMOKE_FAIL=0

smoke_python() {
    channel python git smoke_python_git
    channel python registry smoke_python_registry
}

smoke_python_git() {
    _wd="$(workdir python-git)"
    run_docker_root "python:3.13-alpine" "${_wd}" '
set -eu
apk add --no-cache git >/dev/null
export PIP_CACHE_DIR=/tmp/pip-cache
python -m venv /tmp/venv
. /tmp/venv/bin/activate
pip install -q "git+https://github.com/dotmonk/wildling.git@'"${TAG}"'#subdirectory=python"
wildling --version | grep -F "'"${VERSION}"'"
[ "$(wildling ab)" = ab ]
python -c "
from wildling import create_wildling
w = create_wildling(patterns=[\"ab\"])
assert w.count() == 1
assert w.get(0) == \"ab\"
"
'
}

smoke_python_registry() {
    _wd="$(workdir python-registry)"
    run_docker "python:3.13-alpine" "${_wd}" '
set -eu
export PIP_CACHE_DIR=/tmp/pip-cache
python -m venv /tmp/venv
. /tmp/venv/bin/activate
pip install -q "wildling=='"${VERSION}"'"
wildling --version | grep -F "'"${VERSION}"'"
[ "$(wildling ab)" = ab ]
python -c "
from wildling import create_wildling
w = create_wildling(patterns=[\"ab\"])
assert w.count() == 1
assert w.get(0) == \"ab\"
"
' -e PIP_CACHE_DIR=/tmp/pip-cache
}

smoke_python

if [ "$SMOKE_FAIL" -ne 0 ]; then
    echo "Post-release smoke failed for python." >&2
    exit 1
fi
