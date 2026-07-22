#!/bin/sh
# Mirror swift/ to dotmonk/wildling-swift for SwiftPM (Package.swift at mirror root).
#
# Usage:
#   SWIFT_MIRROR_TOKEN=ghp_... ./scripts/mirror-swift-spm.sh v2.0.0
set -eu

TAG="${1:-}"
if [ -z "$TAG" ]; then
    echo "Usage: $0 <tag>   e.g. v2.0.0" >&2
    exit 1
fi

. "$(dirname "$0")/mirror-ecosystem-lib.sh"
ROOT="$(mirror_ecosystem_root)"
MIRROR_REPO="${SWIFT_MIRROR_REPO:-dotmonk/wildling-swift}"
TOKEN="${SWIFT_MIRROR_TOKEN:-}"
TEMPLATE="$ROOT/scripts/templates/Package.swift"

if [ ! -d "$ROOT/swift/Sources" ]; then
    echo "Missing $ROOT/swift/Sources" >&2
    exit 1
fi

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

mkdir -p "$WORKDIR/Sources" "$WORKDIR/Executable"
rsync -a "$ROOT/swift/Sources/" "$WORKDIR/Sources/"
rsync -a "$ROOT/swift/Executable/" "$WORKDIR/Executable/"
cp "$TEMPLATE" "$WORKDIR/Package.swift"

if [ -f "$ROOT/swift/README.md" ]; then
    cp "$ROOT/swift/README.md" "$WORKDIR/README.md"
fi

mirror_ecosystem_copy_license "$WORKDIR"
mirror_ecosystem_push "$WORKDIR" "$TAG" "$TOKEN" "$MIRROR_REPO" "swift"
