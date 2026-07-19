#!/bin/sh

set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
DOCKER_IMAGE="gcc:14-bookworm"
CONTAINER_WORKDIR="/app"
HOST_UID="$(id -u)"
HOST_GID="$(id -g)"

BUILD_COMMAND='
set -e
mkdir -p dist
gfortran -std=f2018 -O2 -Wall \
  -J dist \
  -o dist/wildling \
  src/util.f90 \
  src/token.f90 \
  src/parse_pattern.f90 \
  src/generator.f90 \
  src/wildling.f90 \
  src/json.f90 \
  src/cli.f90
cp /docs/help.txt dist/help.txt
chown -R '"${HOST_UID}:${HOST_GID}"' dist 2>/dev/null || true
'

docker run --rm \
    -v "${PROJECT_DIR}:${CONTAINER_WORKDIR}" \
    -v "${PROJECT_DIR}/../docs:/docs:ro" \
    -w "${CONTAINER_WORKDIR}" \
    --network=host \
    --user root \
    "${DOCKER_IMAGE}" \
    sh -c "${BUILD_COMMAND}"

exit 0
