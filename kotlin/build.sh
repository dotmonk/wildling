#!/bin/sh

set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
DOCKER_IMAGE="eclipse-temurin:21-jdk-jammy"
CONTAINER_WORKDIR="/app"
KOTLIN_VERSION="2.1.10"
HOST_UID="$(id -u)"
HOST_GID="$(id -g)"

BUILD_COMMAND="
set -e
export DEBIAN_FRONTEND=noninteractive
if ! command -v curl >/dev/null 2>&1 || ! command -v unzip >/dev/null 2>&1; then
    apt-get update -qq
    apt-get install -y -qq curl unzip >/dev/null
fi
if [ ! -x .kotlinc/bin/kotlinc ]; then
    curl -fsSL -o /tmp/kotlin.zip \
        https://github.com/JetBrains/kotlin/releases/download/v${KOTLIN_VERSION}/kotlin-compiler-${KOTLIN_VERSION}.zip
    rm -rf .kotlinc kotlinc
    unzip -q /tmp/kotlin.zip
    mv kotlinc .kotlinc
    rm -f /tmp/kotlin.zip
fi
export PATH=\"/app/.kotlinc/bin:\$PATH\"
rm -rf dist
mkdir -p dist/stage dist/res/wildling
kotlinc src/wildling/*.kt -include-runtime -d dist/wildling-tmp.jar
cp /docs/help.txt dist/res/wildling/help.txt
cd dist/stage
jar xf ../wildling-tmp.jar
cp -r ../res/wildling .
printf 'Manifest-Version: 1.0\nMain-Class: wildling.CliKt\n' > META-INF/MANIFEST.MF
jar cfm ../wildling.jar META-INF/MANIFEST.MF .
cd ../..
rm -rf dist/stage dist/res dist/wildling-tmp.jar
chown -R ${HOST_UID}:${HOST_GID} dist .kotlinc
"

docker run --rm \
    -v "${PROJECT_DIR}:${CONTAINER_WORKDIR}" \
    -v "${PROJECT_DIR}/../docs:/docs:ro" \
    -w "${CONTAINER_WORKDIR}" \
    --network=host \
    "${DOCKER_IMAGE}" \
    sh -c "${BUILD_COMMAND}"

exit 0
