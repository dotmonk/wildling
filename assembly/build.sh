#!/bin/sh

set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
DOCKER_IMAGE="gcc:14-bookworm"
CONTAINER_WORKDIR="/app"
HOST_UID="$(id -u)"
HOST_GID="$(id -g)"

BUILD_COMMAND='
set -e
export DEBIAN_FRONTEND=noninteractive
if ! command -v nasm >/dev/null 2>&1; then
    apt-get update -qq
    apt-get install -y -qq nasm
fi
rm -f src/*.o
mkdir -p dist
for f in src/*.asm; do
    nasm -f elf64 -Isrc -o "${f%.asm}.o" "$f"
done
gcc -o dist/wildling src/*.o
cp /docs/help.txt dist/help.txt
chown -R '"${HOST_UID}:${HOST_GID}"' dist src/*.o 2>/dev/null || true
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
