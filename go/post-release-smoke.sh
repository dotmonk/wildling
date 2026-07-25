#!/bin/sh
# Post-release consumer smoke for go (git/GitHub + registry as documented).
set -eu

LANG_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$LANG_DIR/.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/scripts/post-release-smoke-lib.sh"
post_release_smoke_init

SMOKE_FAIL=0

smoke_go() {
    channel go module smoke_go_module
}

smoke_go_module() {
    _wd="$(workdir go-module)"
    run_docker "golang:1.22-bookworm" "${_wd}" '
set -eu
export GOPATH=/tmp/go
export PATH="$GOPATH/bin:$PATH"
mkdir -p app && cd app
go mod init smoke
go get '"${GO_MOD}"'@'"${TAG}"'
go install '"${GO_MOD}"'/cmd/wildling@'"${TAG}"'
wildling --version | grep -F "'"${VERSION}"'"
[ "$(wildling ab)" = ab ]
cat > main.go <<EOF
package main
import (
  "os"
  "'"${GO_MOD}"'/wildling"
)
func main() {
  w := wildling.New([]string{"ab"}, nil)
  if w.Count() != 1 { os.Exit(1) }
  v, ok := w.Get(0)
  if !ok || v != "ab" { os.Exit(2) }
}
EOF
go run .
'
}

smoke_go

if [ "$SMOKE_FAIL" -ne 0 ]; then
    echo "Post-release smoke failed for go." >&2
    exit 1
fi
