#!/bin/sh

set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
# Target Java 17 bytecode so GitHub Actions' default JRE (often 17) can run dist/.
DOCKER_IMAGE="eclipse-temurin:17-jdk-jammy"
CONTAINER_WORKDIR="/app"
GROOVY_VERSION="4.0.24"
HOST_UID="$(id -u)"
HOST_GID="$(id -g)"

BUILD_COMMAND="
set -e
if [ ! -x .groovy/bin/groovyc ]; then
    curl -fL --connect-timeout 30 --max-time 900 -o /tmp/groovy.zip \
        https://archive.apache.org/dist/groovy/${GROOVY_VERSION}/distribution/apache-groovy-binary-${GROOVY_VERSION}.zip
    rm -rf .groovy groovy-${GROOVY_VERSION}
    mkdir -p /tmp/groovy-extract
    cd /tmp/groovy-extract
    jar xf /tmp/groovy.zip
    mv groovy-${GROOVY_VERSION} /app/.groovy
    chmod +x /app/.groovy/bin/*
    cd /app
    rm -rf /tmp/groovy.zip /tmp/groovy-extract
fi
chmod +x .groovy/bin/* 2>/dev/null || true
export PATH=\"/app/.groovy/bin:\$PATH\"
export GROOVY_HOME=\"/app/.groovy\"
cp /docs/help.txt lib/wildling/help.txt
rm -rf dist
mkdir -p dist/wildling
cp lib/wildling/help.txt dist/wildling/help.txt
groovyc -d dist \\
    lib/wildling/token.groovy \\
    lib/wildling/parse_pattern.groovy \\
    lib/wildling/generator.groovy \\
    lib/wildling/template_json.groovy \\
    lib/wildling/wildling.groovy \\
    lib/wildling/cli.groovy \\
    lib/wildling.groovy
# Syntax-check CLI entry (Groovy 4: -c is --encoding, use groovyc)
mkdir -p /tmp/wildling-entry-check
groovyc -cp dist -d /tmp/wildling-entry-check bin/wildling.groovy
rm -rf /tmp/wildling-entry-check
chown -R ${HOST_UID}:${HOST_GID} dist .groovy lib/wildling/help.txt
"

docker run --rm \
    -v "${PROJECT_DIR}:${CONTAINER_WORKDIR}" \
    -v "${PROJECT_DIR}/../docs:/docs:ro" \
    -w "${CONTAINER_WORKDIR}" \
    --network=host \
    "${DOCKER_IMAGE}" \
    sh -c "${BUILD_COMMAND}"

exit 0
