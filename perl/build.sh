#!/bin/sh

set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
DOCKER_IMAGE="python:3.13-alpine"
CONTAINER_WORKDIR="/app"
HOST_UID="$(id -u)"
HOST_GID="$(id -g)"

BUILD_COMMAND="
set -e
apk add --no-cache perl >/dev/null
cp /docs/help.txt lib/Wildling/help.txt
chown ${HOST_UID}:${HOST_GID} lib/Wildling/help.txt
export PERL5LIB=lib
perl -c bin/wildling.pl
perl -c lib/Wildling.pm
for f in lib/Wildling/*.pm; do
    perl -c \"\$f\"
done
"

docker run --rm \
    -v "${PROJECT_DIR}:${CONTAINER_WORKDIR}" \
    -v "${PROJECT_DIR}/../docs:/docs:ro" \
    -w "${CONTAINER_WORKDIR}" \
    --network=host \
    "${DOCKER_IMAGE}" \
    sh -c "${BUILD_COMMAND}"

exit 0
