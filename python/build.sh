#!/bin/sh

set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
DOCKER_IMAGE="python:3.13-alpine"
CONTAINER_WORKDIR="/app"

docker run --rm \
    -v "${PROJECT_DIR}:${CONTAINER_WORKDIR}" \
    -v "${PROJECT_DIR}/../docs:/docs:ro" \
    -w "${CONTAINER_WORKDIR}" \
    --network=host \
    --user "$(id -u):$(id -g)" \
    "${DOCKER_IMAGE}" \
    sh -c "cp /docs/help.txt wildling/help.txt && python -m compileall -q wildling"

exit 0
