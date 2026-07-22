#!/bin/sh
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

FORBIDDEN="
composer.json
package.json
Package.swift
pyproject.toml
pubspec.yaml
Cargo.toml
go.mod
mix.exs
wildling.gemspec
"

fail=0
for name in $FORBIDDEN; do
    if [ -f "$name" ]; then
        echo "Forbidden file at repository root: $name" >&2
        fail=1
    fi
done

if [ "$fail" -ne 0 ]; then
    exit 1
fi
