#!/bin/sh

set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
DOCKER_IMAGE="gcc:14-bookworm"
CONTAINER_WORKDIR="/app"

BUILD_COMMAND='
set -e
mkdir -p dist
g++ -std=c++17 -O2 -Wall -Wextra -pedantic \
  -o dist/wildling \
  src/token.cpp \
  src/parse_pattern.cpp \
  src/generator.cpp \
  src/wildling.cpp \
  src/template_json.cpp \
  src/cli.cpp
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
