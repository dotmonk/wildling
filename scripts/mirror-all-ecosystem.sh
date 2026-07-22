#!/bin/sh
# Push ecosystem mirror repos (PHP, Swift) for one release tag.
#
# Usage:
#   source scripts/ecosystem-repos.env   # local only; never commit
#   ./scripts/mirror-all-ecosystem.sh v2.0.0
set -eu

TAG="${1:-}"
if [ -z "$TAG" ]; then
    echo "Usage: $0 <tag>   e.g. v2.0.0" >&2
    exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [ -f "$ROOT/scripts/ecosystem-repos.env" ]; then
    # shellcheck disable=SC1091
    . "$ROOT/scripts/ecosystem-repos.env"
fi

run_mirror() {
    _name="$1"
    _script="$2"
    _token_var="$3"
    eval "_token=\${${_token_var}:-}"
    if [ -z "$_token" ]; then
        echo "SKIP ${_name} (${_token_var} not set)"
        return 0
    fi
    echo "==> ${_name}"
    "$ROOT/scripts/${_script}" "$TAG"
}

run_mirror "php" "mirror-php-packagist.sh" "PHP_MIRROR_TOKEN"
run_mirror "swift" "mirror-swift-spm.sh" "SWIFT_MIRROR_TOKEN"

echo "Done."
