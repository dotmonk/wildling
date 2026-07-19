#!/bin/sh

set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
DOCKER_IMAGE="eclipse-temurin:21-jdk-alpine"
CONTAINER_WORKDIR="/app"

BUILD_COMMAND='
set -e
rm -rf dist/classes
mkdir -p dist/classes
javac --release 11 -d dist/classes src/wildling/*.java
cp /docs/help.txt dist/classes/wildling/help.txt
jar cfe dist/wildling.jar wildling.Cli -C dist/classes .
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
