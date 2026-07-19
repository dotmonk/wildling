#!/bin/sh

set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
DOCKER_IMAGE="gcc:14-bookworm"
CONTAINER_WORKDIR="/app"

BUILD_COMMAND='
set -e
mkdir -p dist
gcc -std=c11 -O2 -Wall -Wextra -pedantic \
  -o dist/wildling \
  src/util.c \
  src/token.c \
  src/parse_pattern.c \
  src/generator.c \
  src/wildling.c \
  src/json.c \
  src/cli.c
cp /docs/help.txt dist/help.txt
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
