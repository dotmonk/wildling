#!/bin/sh

set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "${PROJECT_DIR}/.." && pwd)"
DOCKER_IMAGE="gcc:14-bookworm"
ALR_VERSION="2.1.1"
ALR_ZIP="alr-${ALR_VERSION}-bin-x86_64-linux.zip"
ALR_URL="https://github.com/alire-project/alire/releases/download/v${ALR_VERSION}/${ALR_ZIP}"
HOST_UID="$(id -u)"
HOST_GID="$(id -g)"

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
# Host bind-mount is owned by UID ${HOST_UID}; git refuses 'dubious ownership' as root.
git config --global --add safe.directory /repo
git config --global --add safe.directory '*'
alr --version
git -C /repo rev-parse --show-toplevel
exec /bin/bash
"

docker run --rm \
    -it \
    -v "${REPO_DIR}:/repo" \
    -v "${REPO_DIR}/docs:/docs:ro" \
    -e GH_TOKEN \
    -e ALIRE_GITHUB_TOKEN \
    -e HOME=/root \
    -w /repo/ada \
    --network=host \
    --user root \
    "${DOCKER_IMAGE}" \
    sh -c "${SETUP_COMMAND}"

exit 0
