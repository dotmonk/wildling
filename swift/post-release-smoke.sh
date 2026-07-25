#!/bin/sh
# Post-release consumer smoke for swift (git/GitHub + registry as documented).
set -eu

LANG_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$LANG_DIR/.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/scripts/post-release-smoke-lib.sh"
post_release_smoke_init

SMOKE_FAIL=0

smoke_swift() {
    channel swift git smoke_swift_git
    channel swift registry smoke_swift_registry
}

smoke_swift_git() {
    smoke_clone_build_cli swift
}

smoke_swift_registry() {
    # SPM identity is the last URL path component (wildling-swift), not Package.swift name.
    _wd="$(workdir swift-registry)"
    run_docker "swift:6.0-bookworm" "${_wd}" '
set -eu
mkdir -p Smoke/Sources/Smoke
cd Smoke
cat > Package.swift <<EOF
// swift-tools-version: 5.9
import PackageDescription
let package = Package(
  name: "Smoke",
  platforms: [.macOS(.v13)],
  dependencies: [
    .package(url: "https://github.com/dotmonk/wildling-swift.git", from: "'"${VERSION}"'"),
  ],
  targets: [
    .executableTarget(
      name: "Smoke",
      dependencies: [.product(name: "Wildling", package: "wildling-swift")]
    ),
  ]
)
EOF
cat > Sources/Smoke/main.swift <<EOF
import Wildling
let w = Wildling(patterns: ["ab"])
guard w.count() == 1 else { fatalError("count") }
guard w.get(0) == "ab" else { fatalError("get") }
print("ok")
EOF
swift run | grep -q ok
'
}

smoke_swift

if [ "$SMOKE_FAIL" -ne 0 ]; then
    echo "Post-release smoke failed for swift." >&2
    exit 1
fi
