#!/bin/sh

set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
DOCKER_IMAGE="dart:stable"
CONTAINER_WORKDIR="/app"

BUILD_COMMAND='
set -e
export PUB_CACHE=/tmp/pub-cache
export HOME=/tmp
mkdir -p dist
cp /docs/help.txt dist/help.txt
dart pub get
dart compile exe bin/wildling.dart -o dist/wildling
'

docker run --rm \
    -v "${PROJECT_DIR}:${CONTAINER_WORKDIR}" \
    -v "${PROJECT_DIR}/../docs:/docs:ro" \
    -w "${CONTAINER_WORKDIR}" \
    --network=host \
    --user "$(id -u):$(id -g)" \
    -e PUB_CACHE=/tmp/pub-cache \
    -e HOME=/tmp \
    "${DOCKER_IMAGE}" \
    sh -c "${BUILD_COMMAND}"

exit 0
