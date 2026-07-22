#!/bin/sh
# Create vX.Y.Z + go/vX.Y.Z tags and a GitHub Release when VERSION is untagged.
# Intended for CI on main after tests pass. Safe to re-run (no-op if tag exists).
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VERSION="$(tr -d '[:space:]' < VERSION)"
TAG="v${VERSION}"
GO_TAG="go/v${VERSION}"

git fetch --tags origin 2>/dev/null || true

if git rev-parse "refs/tags/${TAG}" >/dev/null 2>&1; then
    echo "Tag ${TAG} already exists — nothing to release."
    exit 0
fi

./scripts/sync-version.sh --check

git config user.name "${GIT_AUTHOR_NAME:-github-actions[bot]}"
git config user.email "${GIT_AUTHOR_EMAIL:-41898282+github-actions[bot]@users.noreply.github.com}"

git tag -a "${TAG}" -m "wildling ${VERSION}"
git tag -a "${GO_TAG}" -m "wildling go module ${VERSION}"
git push origin "refs/tags/${TAG}" "refs/tags/${GO_TAG}"

gh release create "${TAG}" \
    --title "wildling ${VERSION}" \
    --generate-notes \
    --verify-tag

echo "Created ${TAG}, ${GO_TAG}, and GitHub Release."
