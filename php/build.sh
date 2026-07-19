#!/bin/sh

set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
DOCKER_IMAGE="php:8.3-cli-alpine"
CONTAINER_WORKDIR="/app"

BUILD_COMMAND='
set -e
cp /docs/help.txt help.txt
php -l bootstrap.php
php -l bin/wildling.php
for f in src/*.php; do php -l "$f"; done
'

docker run --rm \
    -v "${PROJECT_DIR}:${CONTAINER_WORKDIR}" \
    -v "${PROJECT_DIR}/../docs:/docs:ro" \
    -w "${CONTAINER_WORKDIR}" \
    --network=host \
    --user "$(id -u):$(id -g)" \
    "${DOCKER_IMAGE}" \
    sh -c "${BUILD_COMMAND}"

exit 0
