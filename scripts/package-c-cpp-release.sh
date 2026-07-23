#!/bin/sh
# Build C and C++ CLI binaries and stage GitHub Release assets under dist/release/.
#
# Usage (from repo root):
#   ./scripts/package-c-cpp-release.sh [VERSION]
#
# Produces:
#   dist/release/wildling-c-VERSION-linux-x86_64.tar.gz
#   dist/release/wildling-cpp-VERSION-linux-x86_64.tar.gz
#   dist/release/wildling-c-VERSION-src.tar.gz
#   dist/release/wildling-cpp-VERSION-src.tar.gz
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VERSION="${1:-$(tr -d '[:space:]' < VERSION)}"
OUT="$ROOT/dist/release"
rm -rf "$OUT"
mkdir -p "$OUT"

echo "Building C CLI..."
(cd c && ./build.sh)
echo "Building C++ CLI..."
(cd cpp && ./build.sh)

stage_bin() {
    _lang="$1"
    _bin_dir="$2"
    _name="wildling-${_lang}-${VERSION}-linux-x86_64"
    _stage="$OUT/$_name"
    mkdir -p "$_stage"
    cp "${_bin_dir}/wildling" "$_stage/wildling"
    cp "${_bin_dir}/help.txt" "$_stage/help.txt"
    printf '%s\n' "$VERSION" >"$_stage/VERSION"
    tar -C "$OUT" -czf "$OUT/${_name}.tar.gz" "$_name"
    rm -rf "$_stage"
    echo "Wrote $OUT/${_name}.tar.gz"
}

stage_src() {
    _lang="$1"
    _src_root="$2"
    _name="wildling-${_lang}-${VERSION}-src"
    _stage="$OUT/$_name"
    mkdir -p "$_stage"
    # Portable tree for library + CLI consumers (no Docker build.sh required to compile).
    cp -a "${_src_root}/src" "$_stage/"
    cp "${_src_root}/CMakeLists.txt" "$_stage/"
    cp "${_src_root}/README.md" "$_stage/"
    cp "$ROOT/LICENSE" "$_stage/"
    cp "$ROOT/docs/help.txt" "$_stage/help.txt"
    printf '%s\n' "$VERSION" >"$_stage/VERSION"
    tar -C "$OUT" -czf "$OUT/${_name}.tar.gz" "$_name"
    rm -rf "$_stage"
    echo "Wrote $OUT/${_name}.tar.gz"
}

stage_bin c c/dist
stage_bin cpp cpp/dist
stage_src c c
stage_src cpp cpp

ls -la "$OUT"
