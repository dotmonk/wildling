#!/bin/sh

set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
DOCKER_IMAGE="ruby:3.3-alpine"
CONTAINER_WORKDIR="/app"

BUILD_COMMAND='
set -e
cp /docs/help.txt lib/wildling/help.txt
ruby -c bin/wildling.rb
ruby -c lib/wildling.rb
for f in lib/wildling/*.rb; do ruby -c "$f"; done
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
