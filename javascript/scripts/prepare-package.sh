#!/bin/sh
# Build dist/ when missing (git installs and local dev). No-op if already built.
set -eu
cd "$(dirname "$0")/.."
if [ -f dist/index.js ]; then
    exit 0
fi
npm run build
