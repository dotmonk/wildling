#!/bin/sh

set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
DOCKER_IMAGE="mcr.microsoft.com/powershell"
CONTAINER_WORKDIR="/app"
HOST_UID="$(id -u)"
HOST_GID="$(id -g)"

BUILD_COMMAND='
set -e
cp /docs/help.txt help.txt
pwsh -NoProfile -Command "
    \$LibDir = \"/app/lib\"
    . \"\$LibDir/Wildling.Token.ps1\"
    . \"\$LibDir/Wildling.ParsePattern.ps1\"
    . \"\$LibDir/Wildling.Generator.ps1\"
    . \"\$LibDir/Wildling.ps1\"
    . \"\$LibDir/Wildling.Cli.ps1\"
"
pwsh -NoProfile -File bin/wildling.ps1 --version >/dev/null
'

run_build() {
    docker run --rm \
        -v "${PROJECT_DIR}:${CONTAINER_WORKDIR}" \
        -v "${PROJECT_DIR}/../docs:/docs:ro" \
        -w "${CONTAINER_WORKDIR}" \
        --network=host \
        "$@"
}

if run_build --user "${HOST_UID}:${HOST_GID}" "${DOCKER_IMAGE}" sh -c "${BUILD_COMMAND}" 2>/dev/null; then
    exit 0
fi

run_build "${DOCKER_IMAGE}" sh -c "${BUILD_COMMAND}
chown ${HOST_UID}:${HOST_GID} help.txt 2>/dev/null || true
"

exit 0
