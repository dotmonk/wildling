#!/bin/sh
# Build registry publish artifacts locally without uploading (Docker).
# Invoked by ./test.sh --publish-artifacts (and after a full ./test.sh).
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

UID_GID="$(id -u):$(id -g)"
fail=0

# Match language build.sh images; alpine is what CI already pulls for csharp/vb/fsharp.
DOTNET_SDK_IMAGE="mcr.microsoft.com/dotnet/sdk:8.0-alpine"

docker_pull() {
    _image="$1"
    _attempt=1
    while [ "${_attempt}" -le 3 ]; do
        if docker pull "${_image}"; then
            return 0
        fi
        echo "docker pull failed for ${_image} (attempt ${_attempt}/3); retrying…" >&2
        _attempt=$((_attempt + 1))
        sleep $((_attempt * 2))
    done
    echo "docker pull failed for ${_image}" >&2
    return 1
}

run_docker() {
    _image="$1"
    _workdir="$2"
    _cmd="$3"
    shift 3
    docker_pull "${_image}" || return 1
    docker run --rm \
        -v "${ROOT}:${ROOT}" \
        -v "${ROOT}/docs:/docs:ro" \
        -w "${ROOT}/${_workdir}" \
        --network=host \
        --user "${UID_GID}" \
        "$@" \
        "${_image}" \
        sh -c "${_cmd}"
}

smoke() {
    _name="$1"
    shift
    echo "==> publish artifact: ${_name}"
    if ! "$@"; then
        echo "FAIL: ${_name}" >&2
        fail=1
        return 0
    fi
    echo "OK: ${_name}"
}

smoke_npm() {
    run_docker "node:24.10-alpine" "javascript" '
set -e
export HOME=/tmp
export npm_config_cache=/tmp/.npm
npm ci --include=dev
npm run build
cp /docs/help.txt dist/help.txt
cp package.json /tmp/package.json.bak
node -e "const fs=require(\"fs\"); const p=JSON.parse(fs.readFileSync(\"package.json\",\"utf8\")); p.private=false; fs.writeFileSync(\"package.json\", JSON.stringify(p,null,2)+\"\\n\")"
npm pack --pack-destination /tmp
ls /tmp/wildling-*.tgz
mv /tmp/package.json.bak package.json
' -e HOME=/tmp -e npm_config_cache=/tmp/.npm
}

smoke_pypi() {
    run_docker "python:3.12-bookworm" "python" '
set -e
export HOME=/tmp
export PIP_CACHE_DIR=/tmp/pip-cache
python -m pip install --quiet --upgrade build twine
cp /docs/help.txt wildling/help.txt
rm -rf dist build *.egg-info wildling.egg-info
python -m build
python -m twine check dist/*
ls dist/*.whl dist/*.tar.gz
' -e HOME=/tmp -e PIP_CACHE_DIR=/tmp/pip-cache
}

smoke_crates() {
    run_docker "rust:1.83-bookworm" "rust" '
set -e
export CARGO_HOME=/tmp/cargo
cp /docs/help.txt help.txt 2>/dev/null || true
cargo package --allow-dirty --no-verify
ls target/package/wildling-*.crate
' -e CARGO_HOME=/tmp/cargo
}

smoke_gem() {
    run_docker "ruby:3.3-bookworm" "ruby" '
set -e
cp /docs/help.txt help.txt
rm -f wildling-*.gem
gem build wildling.gemspec
ls wildling-*.gem
'
}

smoke_pub() {
    run_docker "dart:stable" "dart" '
set -e
export PUB_CACHE=/tmp/pub-cache
export HOME=/tmp
cp /docs/help.txt help.txt 2>/dev/null || true
# Dry-run in a copy so a dirty monorepo working tree is not treated as failure
rm -rf /tmp/dart-smoke
mkdir -p /tmp/dart-smoke
cp -a . /tmp/dart-smoke/
# Drop nested git metadata if present via bind mount
rm -rf /tmp/dart-smoke/.git
cd /tmp/dart-smoke
dart pub get
dart pub publish --dry-run
' -e PUB_CACHE=/tmp/pub-cache -e HOME=/tmp
}

smoke_nuget() {
    _dir="$1"
    run_docker "${DOTNET_SDK_IMAGE}" "${_dir}" '
set -e
export HOME=/tmp
export DOTNET_CLI_HOME=/tmp/dotnet
export DOTNET_NOLOGO=1
export DOTNET_SKIP_FIRST_TIME_EXPERIENCE=1
mkdir -p "$DOTNET_CLI_HOME"
cp /docs/help.txt help.txt
rm -rf nupkg
dotnet pack -c Release -o ./nupkg
ls ./nupkg/*.nupkg
' -e HOME=/tmp -e DOTNET_CLI_HOME=/tmp/dotnet -e DOTNET_NOLOGO=1 -e DOTNET_SKIP_FIRST_TIME_EXPERIENCE=1
}

smoke_hex() {
    run_docker "elixir:1.16-otp-26" "elixir" '
set -e
export HOME=/tmp
export MIX_HOME=/tmp/mix
export HEX_HOME=/tmp/hex
mix local.hex --force --if-missing
cp /docs/help.txt lib/wildling/help.txt 2>/dev/null || true
mix hex.build
ls wildling-*.tar
' -e HOME=/tmp -e MIX_HOME=/tmp/mix -e HEX_HOME=/tmp/hex
}

smoke_maven() {
    run_docker "maven:3.9-eclipse-temurin-17" "java" '
set -e
cp /docs/help.txt help.txt 2>/dev/null || true
mvn -B -DskipTests package
ls target/*.jar
'
}

echo "Smoke-building publish artifacts (no upload)"
echo

smoke npm smoke_npm
smoke pypi smoke_pypi
smoke crates smoke_crates
smoke rubygems smoke_gem
smoke pubdev smoke_pub
smoke "nuget (csharp)" smoke_nuget csharp
smoke "nuget (fsharp)" smoke_nuget fsharp
smoke "nuget (visualbasic)" smoke_nuget visualbasic
smoke hex smoke_hex
smoke maven smoke_maven

echo
if [ "$fail" -ne 0 ]; then
    echo "Publish artifact smoke tests failed." >&2
    exit 1
fi
echo "All publish artifact smoke tests passed!"
