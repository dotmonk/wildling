#!/bin/sh

set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
DOCKER_IMAGE="golang:1.22-bookworm"
CONTAINER_WORKDIR="/app"

BUILD_COMMAND='
set -e
mkdir -p dist
cp /docs/help.txt dist/help.txt
CGO_ENABLED=0 go build -o dist/wildling ./cmd/wildling
'

docker run --rm \
    -v "${PROJECT_DIR}:${CONTAINER_WORKDIR}" \
    -v "${PROJECT_DIR}/../docs:/docs:ro" \
    -w "${CONTAINER_WORKDIR}" \
    --network=host \
    --user "$(id -u):$(id -g)" \
    -e GOCACHE=/tmp/go-cache \
    -e GOMODCACHE=/tmp/go-mod \
    "${DOCKER_IMAGE}" \
    sh -c "${BUILD_COMMAND}"

exit 0
