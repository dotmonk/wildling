#!/bin/sh
# Post-release consumer smoke: dispatch to <lang>/post-release-smoke.sh
# Invoked by ./post-release-smoke-test.sh
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# shellcheck disable=SC1091
. "$ROOT/scripts/post-release-smoke-lib.sh"
post_release_smoke_init

SELECTED="${WILDLING_SMOKE_LANGUAGES:-}"
if [ -z "$SELECTED" ]; then
    SELECTED="$(grep -v '^[[:space:]]*#' "$ROOT/languages.txt" | grep -v '^[[:space:]]*$')"
fi

echo "Post-release smoke: tag=${TAG} version=${VERSION} workdir=${SMOKE_ROOT}"

fail=0
for language in $SELECTED; do
    script="$ROOT/$language/post-release-smoke.sh"
    if [ ! -x "$script" ]; then
        echo "Unknown or unsmokeable language: $language" >&2
        echo "Expected executable: $language/post-release-smoke.sh" >&2
        fail=1
        continue
    fi
    # Share the same workdir/tag across languages in one run
    if ! env \
        ROOT="$ROOT" \
        TAG="$TAG" \
        VERSION="$VERSION" \
        SMOKE_ROOT="$SMOKE_ROOT" \
        REPO_URL="$REPO_URL" \
        REPO_SLUG="$REPO_SLUG" \
        GO_MOD="$GO_MOD" \
        WILDLING_SMOKE_TAG="$TAG" \
        WILDLING_SMOKE_WORKDIR="$SMOKE_ROOT" \
        "$script"
    then
        fail=1
    fi
done

echo
if [ "$fail" -ne 0 ]; then
    echo "Post-release smoke tests failed." >&2
    exit 1
fi
echo "All post-release smoke tests passed!"
