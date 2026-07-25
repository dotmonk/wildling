#!/bin/sh

set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
DOCKER_IMAGE="python:3.13-alpine"
CONTAINER_WORKDIR="/app"
HOST_UID="$(id -u)"
HOST_GID="$(id -g)"

# Match build.sh: Alpine image has no Perl until apk installs it.
# make is needed for Makefile.PL / make manifest / make dist.
docker run --rm \
    -it \
    -v "${PROJECT_DIR}:${CONTAINER_WORKDIR}" \
    -v "${PROJECT_DIR}/../docs:/docs:ro" \
    -w "${CONTAINER_WORKDIR}" \
    -e "HOST_UID=${HOST_UID}" \
    -e "HOST_GID=${HOST_GID}" \
    --network=host \
    "${DOCKER_IMAGE}" \
    sh -c 'apk add --no-cache perl make >/dev/null && exec /bin/sh'

exit 0
