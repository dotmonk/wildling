#!/bin/sh

set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
DOCKER_IMAGE="gcc:14-bookworm"
CONTAINER_WORKDIR="/app"
ALR_VERSION="2.1.1"
ALR_ZIP="alr-${ALR_VERSION}-bin-x86_64-linux.zip"
ALR_URL="https://github.com/alire-project/alire/releases/download/v${ALR_VERSION}/${ALR_ZIP}"

SETUP_COMMAND="
set -e
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq --no-install-recommends \\
  gnat gprbuild curl ca-certificates unzip git >/dev/null
curl -fsSL '${ALR_URL}' -o /tmp/alr.zip
rm -rf /tmp/alr
unzip -qo /tmp/alr.zip -d /tmp/alr
ALR_BIN=\"\$(find /tmp/alr -type f -name alr | head -n 1)\"
install -m 755 \"\$ALR_BIN\" /usr/local/bin/alr
alr --version
exec /bin/bash
"

docker run --rm \
    -it \
    -v "${PROJECT_DIR}:${CONTAINER_WORKDIR}" \
    -v "${PROJECT_DIR}/../docs:/docs:ro" \
    -v "${PROJECT_DIR}/..:/repo:ro" \
    -e GH_TOKEN \
    -e ALIRE_GITHUB_TOKEN \
    -w "${CONTAINER_WORKDIR}" \
    --network=host \
    --user root \
    "${DOCKER_IMAGE}" \
    sh -c "${SETUP_COMMAND}"

exit 0
