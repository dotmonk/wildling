#!/bin/sh

set -e
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_DIR"

CURRENT=$(cat VERSION)
MAJOR=$(echo "$CURRENT" | cut -d. -f1)
MINOR=$(echo "$CURRENT" | cut -d. -f2)
PATCH=$(echo "$CURRENT" | cut -d. -f3)
NEW_PATCH=$((PATCH + 1))
NEW_VERSION="$MAJOR.$MINOR.$NEW_PATCH"

echo "$NEW_VERSION" > VERSION

./scripts/sync-version.sh
./build.sh

echo
echo "VERSION is now ${NEW_VERSION}."
echo "Commit and push to main; CI will create tags v${NEW_VERSION} / go/v${NEW_VERSION}"
echo "and a GitHub Release after tests pass."
