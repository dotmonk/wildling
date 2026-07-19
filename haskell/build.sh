#!/bin/sh

set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
DOCKER_IMAGE="gcc:14-bookworm"
CONTAINER_WORKDIR="/app"
HOST_UID="$(id -u)"
HOST_GID="$(id -g)"
GHC_VERSION="9.6.6"
ARCH="$(uname -m)"

case "$ARCH" in
    x86_64|amd64) GHC_ARCH="x86_64" ;;
    aarch64|arm64) GHC_ARCH="aarch64" ;;
    *)
        echo "Unsupported architecture: $ARCH" >&2
        exit 1
        ;;
esac

GHC_TARBALL="ghc-${GHC_VERSION}-${GHC_ARCH}-deb11-linux.tar.xz"
GHC_URL="https://downloads.haskell.org/~ghc/${GHC_VERSION}/${GHC_TARBALL}"
GHC_DIR="ghc-${GHC_VERSION}-${GHC_ARCH}-unknown-linux"

BUILD_COMMAND="
set -e
export DEBIAN_FRONTEND=noninteractive
ensure_build_deps() {
    apt-get update -qq
    apt-get install -y -qq --no-install-recommends curl xz-utils make libgmp-dev >/dev/null
}
install_ghc_bindist() {
    ensure_build_deps
    curl -fsSL -o /tmp/ghc.tar.xz \"${GHC_URL}\"
    rm -rf .ghc \"${GHC_DIR}\"
    tar -xJf /tmp/ghc.tar.xz
    cd \"${GHC_DIR}\"
    ./configure --prefix=/app/.ghc
    make install
    cd /app
    rm -rf \"${GHC_DIR}\" /tmp/ghc.tar.xz
}
install_ghc_apt() {
    apt-get update -qq
    apt-get install -y -qq --no-install-recommends ghc >/dev/null
    mkdir -p .ghc/bin
    ln -sfn \"\$(command -v ghc)\" .ghc/bin/ghc
}
if [ ! -x .ghc/bin/ghc ]; then
    if ! install_ghc_bindist; then
        echo \"GHC bindist install failed; falling back to apt ghc\" >&2
        rm -rf .ghc \"${GHC_DIR}\"
        install_ghc_apt
    fi
fi
export PATH=\"/app/.ghc/bin:\$PATH\"
if ! ghc --version >/dev/null 2>&1; then
    install_ghc_apt
    export PATH=\"/app/.ghc/bin:\$PATH\"
fi
rm -rf dist
mkdir -p dist/obj
ghc -O2 -isrc -outputdir dist/obj -o dist/wildling src/Main.hs
cp /docs/help.txt dist/help.txt
chown -R ${HOST_UID}:${HOST_GID} dist .ghc 2>/dev/null || true
"

docker run --rm \
    -v "${PROJECT_DIR}:${CONTAINER_WORKDIR}" \
    -v "${PROJECT_DIR}/../docs:/docs:ro" \
    -w "${CONTAINER_WORKDIR}" \
    --network=host \
    "${DOCKER_IMAGE}" \
    sh -c "${BUILD_COMMAND}"

exit 0
