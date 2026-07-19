#!/bin/sh

set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
DOCKER_IMAGE="swift:6.0-bookworm"
CONTAINER_WORKDIR="/app"

BUILD_COMMAND='
set -e
mkdir -p dist /tmp/swift-module-cache
cp /docs/help.txt dist/help.txt
# Deterministic source order for swiftc
swiftc -O -static-stdlib \
    -module-cache-path /tmp/swift-module-cache \
    Sources/Token.swift \
    Sources/ParsePattern.swift \
    Sources/Generator.swift \
    Sources/Wildling.swift \
    Sources/Cli.swift \
    Sources/main.swift \
    -o dist/wildling
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
