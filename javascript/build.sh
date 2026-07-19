#!/bin/sh

set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
DOCKER_IMAGE="node:24.10-alpine"
CONTAINER_WORKDIR="/app"
# Install build tooling (devDependencies) even when NODE_ENV would omit them.
# docs/ is mounted at /docs because only javascript/ is bind-mounted as /app.
# HOME/npm cache must be writable: --user drops to a UID with no /home entry
# (GitHub Actions runners hit EACCES on /.npm without this).
BUILD_COMMAND='
set -e
export HOME=/tmp
export npm_config_cache=/tmp/.npm
npm ci --include=dev
npx tsc --build --force
cp /docs/help.txt dist/help.txt
'

docker run --rm \
    -v "${PROJECT_DIR}:${CONTAINER_WORKDIR}" \
    -v "${PROJECT_DIR}/../docs:/docs:ro" \
    -w "${CONTAINER_WORKDIR}" \
    --network=host \
    --user "$(id -u):$(id -g)" \
    -e HOME=/tmp \
    -e npm_config_cache=/tmp/.npm \
    "${DOCKER_IMAGE}" \
    sh -c "${BUILD_COMMAND}"

exit 0
