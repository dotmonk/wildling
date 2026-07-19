#!/bin/sh

set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
DOCKER_IMAGE="gcc:14-bookworm"
CONTAINER_WORKDIR="/app"
HOST_UID="$(id -u)"
HOST_GID="$(id -g)"

BUILD_COMMAND="
set -e
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq >/dev/null
apt-get install -y -qq --no-install-recommends elixir >/dev/null
cp /docs/help.txt lib/wildling/help.txt
# Cache Elixir + Erlang into the project (like scala/.scala) for host runs.
if [ ! -x .elixir/elixir/bin/elixir ] || [ ! -x .elixir/erlang/erts-*/bin/erlexec ]; then
    rm -rf .elixir
    mkdir -p .elixir
    cp -a /usr/lib/erlang .elixir/erlang
    cp -a /usr/lib/elixir .elixir/elixir
    # Debian erl hardcodes ROOTDIR=/usr/lib/erlang; make it relocatable.
    for f in .elixir/erlang/bin/erl .elixir/erlang/erts-*/bin/erl; do
        [ -f \"\$f\" ] || continue
        sed -i 's|ROOTDIR=/usr/lib/erlang|ROOTDIR=\"\${dyn_rootdir:-\$(cd \"\$(dirname \"\$0\")/..\" && pwd)}\"|g' \"\$f\"
    done
fi
export PATH=\"/app/.elixir/elixir/bin:/app/.elixir/erlang/bin:\$PATH\"
export ERL_ROOTDIR=\"/app/.elixir/erlang\"
rm -rf ebin
mkdir -p ebin
elixirc -o ebin \\
    lib/wildling/token.ex \\
    lib/wildling/parse_pattern.ex \\
    lib/wildling/generator.ex \\
    lib/wildling/json.ex \\
    lib/wildling.ex \\
    lib/wildling/cli.ex
cp lib/wildling/help.txt ebin/help.txt
chown -R ${HOST_UID}:${HOST_GID} ebin .elixir lib/wildling/help.txt
"

docker run --rm \
    -v "${PROJECT_DIR}:${CONTAINER_WORKDIR}" \
    -v "${PROJECT_DIR}/../docs:/docs:ro" \
    -w "${CONTAINER_WORKDIR}" \
    --network=host \
    "${DOCKER_IMAGE}" \
    sh -c "${BUILD_COMMAND}"

exit 0
