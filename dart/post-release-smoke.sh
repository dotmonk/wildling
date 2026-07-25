#!/bin/sh
# Post-release consumer smoke for dart (git/GitHub + registry as documented).
set -eu

LANG_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$LANG_DIR/.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/scripts/post-release-smoke-lib.sh"
post_release_smoke_init

SMOKE_FAIL=0

smoke_dart() {
    channel dart git smoke_dart_git
    channel dart registry smoke_dart_registry
}

smoke_dart_git() {
    _wd="$(workdir dart-git)"
    run_docker "dart:stable" "${_wd}" '
set -eu
mkdir -p app && cd app
dart create -t console-simple . --force >/dev/null
dart pub add wildling --git-url=https://github.com/dotmonk/wildling.git --git-path=dart --git-ref='"${TAG}"'
cat > bin/app.dart <<EOF
import "package:wildling/wildling.dart";
void main() {
  final w = Wildling(["ab"]);
  if (w.count() != 1) throw "count";
  if (w.get(0) != "ab") throw "get";
  print("ok");
}
EOF
dart run | grep -q ok
'
}

smoke_dart_registry() {
    _wd="$(workdir dart-registry)"
    run_docker "dart:stable" "${_wd}" '
set -eu
mkdir -p app && cd app
dart create -t console-simple . --force >/dev/null
dart pub add "wildling:'"${VERSION}"'"
cat > bin/app.dart <<EOF
import "package:wildling/wildling.dart";
void main() {
  final w = Wildling(["ab"]);
  if (w.count() != 1) throw "count";
  if (w.get(0) != "ab") throw "get";
  print("ok");
}
EOF
dart run | grep -q ok
'
}

smoke_dart

if [ "$SMOKE_FAIL" -ne 0 ]; then
    echo "Post-release smoke failed for dart." >&2
    exit 1
fi
