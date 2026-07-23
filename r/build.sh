#!/bin/sh

set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
DOCKER_IMAGE="gcc:14-bookworm"
CONTAINER_WORKDIR="/app"
HOST_UID="$(id -u)"
HOST_GID="$(id -g)"

BUILD_COMMAND="
set -e
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq >/dev/null
apt-get install -y -qq --no-install-recommends r-base-core >/dev/null
mkdir -p inst
cp /docs/help.txt inst/help.txt
chown ${HOST_UID}:${HOST_GID} inst/help.txt
Rscript --version >/dev/null
Rscript -e \"for (f in c(Sys.glob('R/*.R'), 'bin/wildling.R')) parse(file=f)\"
"

docker run --rm \
    -v "${PROJECT_DIR}:${CONTAINER_WORKDIR}" \
    -v "${PROJECT_DIR}/../docs:/docs:ro" \
    -w "${CONTAINER_WORKDIR}" \
    --network=host \
    "${DOCKER_IMAGE}" \
    sh -c "${BUILD_COMMAND}"

exit 0
