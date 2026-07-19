#!/bin/sh

set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
DOCKER_IMAGE="gcc:14-bookworm"
CONTAINER_WORKDIR="/app"
ZIG_VERSION="0.13.0"
HOST_UID="$(id -u)"
HOST_GID="$(id -g)"
ARCH="$(uname -m)"

case "$ARCH" in
    x86_64|amd64) ZIG_ARCH="x86_64" ;;
    aarch64|arm64) ZIG_ARCH="aarch64" ;;
    *)
        echo "Unsupported architecture: $ARCH" >&2
        exit 1
        ;;
esac

BUILD_COMMAND="
set -e
export DEBIAN_FRONTEND=noninteractive
if ! command -v curl >/dev/null 2>&1 || ! command -v xz >/dev/null 2>&1 || ! command -v tar >/dev/null 2>&1; then
    apt-get update -qq
    apt-get install -y -qq curl xz-utils tar >/dev/null
fi
if [ ! -x .zig/zig ]; then
    curl -fsSL -o /tmp/zig.tar.xz \\
        https://ziglang.org/download/${ZIG_VERSION}/zig-linux-${ZIG_ARCH}-${ZIG_VERSION}.tar.xz
    rm -rf .zig zig-linux-${ZIG_ARCH}-${ZIG_VERSION}
    tar -xJf /tmp/zig.tar.xz
    mv zig-linux-${ZIG_ARCH}-${ZIG_VERSION} .zig
    rm -f /tmp/zig.tar.xz
fi
export PATH=\"/app/.zig:\$PATH\"
rm -rf dist zig-out zig-cache .zig-cache
mkdir -p dist
zig build -Doptimize=ReleaseSafe
cp zig-out/bin/wildling dist/wildling
cp /docs/help.txt dist/help.txt
chown -R ${HOST_UID}:${HOST_GID} dist .zig zig-out 2>/dev/null || true
rm -rf zig-cache .zig-cache
"

docker run --rm \
    -v "${PROJECT_DIR}:${CONTAINER_WORKDIR}" \
    -v "${PROJECT_DIR}/../docs:/docs:ro" \
    -w "${CONTAINER_WORKDIR}" \
    --network=host \
    "${DOCKER_IMAGE}" \
    sh -c "${BUILD_COMMAND}"

exit 0
