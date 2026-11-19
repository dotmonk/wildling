#!/bin/sh
# Post-release consumer smoke for rust (git/GitHub + registry as documented).
set -eu

LANG_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$LANG_DIR/.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/scripts/post-release-smoke-lib.sh"
post_release_smoke_init

SMOKE_FAIL=0

smoke_rust() {
    channel rust git smoke_rust_git
    channel rust registry smoke_rust_registry
}

smoke_rust_git() {
    # Cargo forbids combining git= and path=; install from a tagged clone (documented monorepo layout).
    _wd="$(workdir rust-git)"
    clone_tag "${_wd}/repo" || return 1
    run_docker "rust:1.83-bookworm" "${_wd}" '
set -eu
mkdir -p app && cd app
cargo init --name smoke --bin >/dev/null
cat >> Cargo.toml <<EOF
wildling = { path = "/work/repo/rust" }
EOF
cat > src/main.rs <<EOF
use wildling::{Dictionaries, Wildling};
fn main() {
    let dicts = Dictionaries::new();
    let mut w = Wildling::new(&["ab".to_string()], &dicts);
    assert_eq!(w.count(), 1);
    assert_eq!(w.get(0).as_deref(), Some("ab"));
    assert_eq!(w.next().as_deref(), Some("ab"));
}
EOF
cargo run -q
cargo install --path /work/repo/rust --force
export PATH="$HOME/.cargo/bin:$PATH"
wildling --version | grep -F "'"${VERSION}"'"
[ "$(wildling ab)" = ab ]
'
}

smoke_rust_registry() {
    _wd="$(workdir rust-registry)"
    run_docker "rust:1.83-bookworm" "${_wd}" '
set -eu
cargo install wildling --version "'"${VERSION}"'"
export PATH="$HOME/.cargo/bin:$PATH"
wildling --version | grep -F "'"${VERSION}"'"
[ "$(wildling ab)" = ab ]
mkdir -p app && cd app
cargo init --name smoke --bin >/dev/null
cargo add wildling@'"${VERSION}"'
cat > src/main.rs <<EOF
use wildling::{Dictionaries, Wildling};
fn main() {
    let dicts = Dictionaries::new();
    let mut w = Wildling::new(&["ab".to_string()], &dicts);
    assert_eq!(w.count(), 1);
    assert_eq!(w.get(0).as_deref(), Some("ab"));
}
EOF
cargo run -q
'
}

smoke_rust

if [ "$SMOKE_FAIL" -ne 0 ]; then
    echo "Post-release smoke failed for rust." >&2
    exit 1
fi
