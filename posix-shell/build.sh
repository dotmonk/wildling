#!/bin/sh

set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
DOCKER_IMAGE="python:3.13-alpine"
CONTAINER_WORKDIR="/app"

BUILD_COMMAND='
set -e
cp /docs/help.txt help.txt
sh -n lib/wildling.sh
sh -n bin/wildling
for f in lib/*.awk; do
    awk -f "$f" -v data_file=/dev/null -v mode=check -v check_patterns="" </dev/null >/dev/null 2>&1 || true
done
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
