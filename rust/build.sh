#!/bin/sh

set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
DOCKER_IMAGE="rust:1.83-bookworm"
CONTAINER_WORKDIR="/app"

BUILD_COMMAND='
set -e
mkdir -p dist
cargo build --release
cp target/release/wildling dist/wildling
cp /docs/help.txt dist/help.txt
'

docker run --rm \
    -v "${PROJECT_DIR}:${CONTAINER_WORKDIR}" \
    -v "${PROJECT_DIR}/../docs:/docs:ro" \
    -w "${CONTAINER_WORKDIR}" \
    --network=host \
    --user "$(id -u):$(id -g)" \
    -e CARGO_HOME=/tmp/cargo \
    "${DOCKER_IMAGE}" \
    sh -c "${BUILD_COMMAND}"

exit 0
