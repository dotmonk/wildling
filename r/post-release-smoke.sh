#!/bin/sh
# Post-release consumer smoke for r (git/GitHub + registry as documented).
set -eu

LANG_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$LANG_DIR/.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/scripts/post-release-smoke-lib.sh"
post_release_smoke_init

SMOKE_FAIL=0

smoke_r() {
    channel r git smoke_r_git
    channel r registry smoke_r_registry
}

smoke_r_git() {
    _wd="$(workdir r-git)"
    run_docker_root "r-base:4.4.2" "${_wd}" '
set -eu
apt-get update -qq
apt-get install -y -qq git libcurl4-openssl-dev libssl-dev >/dev/null
Rscript -e "install.packages(\"remotes\", repos=\"https://cloud.r-project.org\")"
Rscript -e "remotes::install_github(\"dotmonk/wildling\", subdir=\"r\", ref=\"'"${TAG}"'\", upgrade=\"never\")"
Rscript -e "
library(wildling)
w <- create_wildling(c(\"ab\"))
stopifnot(w\$count() == 1)
stopifnot(w\$get(0) == \"ab\")
"
'
}

smoke_r_registry() {
    _wd="$(workdir r-registry)"
    run_docker_root "r-base:4.4.2" "${_wd}" '
set -eu
Rscript -e "install.packages(\"wildling\", repos=\"https://dotmonk.r-universe.dev\")"
Rscript -e "
library(wildling)
w <- create_wildling(c(\"ab\"))
stopifnot(w\$count() == 1)
stopifnot(w\$get(0) == \"ab\")
"
'
}

smoke_r

if [ "$SMOKE_FAIL" -ne 0 ]; then
    echo "Post-release smoke failed for r." >&2
    exit 1
fi
