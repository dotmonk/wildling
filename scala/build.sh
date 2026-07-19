#!/bin/sh

set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
DOCKER_IMAGE="eclipse-temurin:21-jdk-jammy"
CONTAINER_WORKDIR="/app"
SCALA_VERSION="2.13.15"
HOST_UID="$(id -u)"
HOST_GID="$(id -g)"

BUILD_COMMAND="
set -e
export DEBIAN_FRONTEND=noninteractive
if ! command -v curl >/dev/null 2>&1 || ! command -v tar >/dev/null 2>&1; then
    apt-get update -qq
    apt-get install -y -qq curl tar gzip >/dev/null
fi
if [ ! -x .scala/bin/scalac ]; then
    curl -fsSL -o /tmp/scala.tgz \
        https://github.com/scala/scala/releases/download/v${SCALA_VERSION}/scala-${SCALA_VERSION}.tgz
    rm -rf .scala scala-${SCALA_VERSION}
    tar -xzf /tmp/scala.tgz
    mv scala-${SCALA_VERSION} .scala
    rm -f /tmp/scala.tgz
fi
export PATH=\"/app/.scala/bin:\$PATH\"
rm -rf dist
mkdir -p dist/classes dist/stage
scalac -d dist/classes src/wildling/*.scala
cp /docs/help.txt dist/classes/wildling/help.txt
cd dist/stage
jar xf /app/.scala/lib/scala-library.jar
cp -r ../classes/* .
printf 'Manifest-Version: 1.0\nMain-Class: wildling.Cli\n' > META-INF/MANIFEST.MF
jar cfm ../wildling.jar META-INF/MANIFEST.MF .
cd ../..
rm -rf dist/stage dist/classes
chown -R ${HOST_UID}:${HOST_GID} dist .scala
"

docker run --rm \
    -v "${PROJECT_DIR}:${CONTAINER_WORKDIR}" \
    -v "${PROJECT_DIR}/../docs:/docs:ro" \
    -w "${CONTAINER_WORKDIR}" \
    --network=host \
    "${DOCKER_IMAGE}" \
    sh -c "${BUILD_COMMAND}"

exit 0
