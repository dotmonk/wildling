#!/bin/sh

set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
DOCKER_IMAGE="mcr.microsoft.com/dotnet/sdk:8.0-alpine"
CONTAINER_WORKDIR="/app"

# shellcheck disable=SC1091
. "${PROJECT_DIR}/../scripts/dotnet-passwd.sh"
PASSWD_FILE="$(dotnet_passwd_file)"
trap 'rm -f "${PASSWD_FILE}"' EXIT

BUILD_COMMAND='
set -e
cp /docs/help.txt help.txt
dotnet publish -c Release -o dist --nologo -v q
'

docker run --rm \
    -v "${PROJECT_DIR}:${CONTAINER_WORKDIR}" \
    -v "${PROJECT_DIR}/../docs:/docs:ro" \
    -w "${CONTAINER_WORKDIR}" \
    --network=host \
    --user "$(id -u):$(id -g)" \
    -v "${PASSWD_FILE}:/etc/passwd:ro" \
    -e DOTNET_CLI_HOME=/tmp/dotnet \
    -e DOTNET_NOLOGO=1 \
    "${DOCKER_IMAGE}" \
    sh -c "${BUILD_COMMAND}"

exit 0
