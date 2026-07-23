#!/bin/sh
# Sync (or verify) every language port version from the root VERSION file.
#
# Usage:
#   ./scripts/sync-version.sh          # write VERSION into all ports
#   ./scripts/sync-version.sh --check  # exit 1 if any port drifts
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VERSION="$(tr -d '[:space:]' < VERSION)"
if ! printf '%s' "$VERSION" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.-]+)?$'; then
    echo "Invalid VERSION: '$VERSION' (expected semver MAJOR.MINOR.PATCH)" >&2
    exit 1
fi

CHECK=0
if [ "${1:-}" = "--check" ] || [ "${1:-}" = "-c" ]; then
    CHECK=1
fi

fail=0
checked=0

# Verify file contains the expected version string (exact occurrence patterns vary).
check_contains() {
    _file="$1"
    _needle="$2"
    checked=$((checked + 1))
    if [ ! -f "$_file" ]; then
        echo "MISSING $_file" >&2
        fail=1
        return
    fi
    if ! grep -Fq "$_needle" "$_file"; then
        echo "DRIFT $_file (expected to contain: $_needle)" >&2
        fail=1
    fi
}

# Args: file, perl s/// expression, expected substring after sync
replace() {
    _file="$1"
    _expr="$2"
    _expect="$3"
    if [ "$CHECK" -eq 1 ]; then
        check_contains "$_file" "$_expect"
        return
    fi
    if [ ! -f "$_file" ]; then
        echo "MISSING $_file" >&2
        fail=1
        return
    fi
    VERSION="$VERSION" perl -i -pe "$_expr" "$_file"
}

# --- library / package version sites ---

replace javascript/package.json \
    's/"version"\s*:\s*"[^"]+"/"version": "$ENV{VERSION}"/' \
    "\"version\": \"$VERSION\""

replace python/pyproject.toml \
    's/^version\s*=\s*"[^"]+"/version = "$ENV{VERSION}"/' \
    "version = \"$VERSION\""

replace python/wildling/__init__.py \
    's/__version__\s*=\s*"[^"]+"/__version__ = "$ENV{VERSION}"/' \
    "__version__ = \"$VERSION\""

replace java/src/wildling/Wildling.java \
    's/VERSION\s*=\s*"[^"]+"/VERSION = "$ENV{VERSION}"/' \
    "VERSION = \"$VERSION\""

replace csharp/Wildling.cs \
    's/Version\s*=\s*"[^"]+"/Version = "$ENV{VERSION}"/' \
    "Version = \"$VERSION\""

replace csharp/Wildling.csproj \
    's/<Version>[^<]+<\/Version>/<Version>$ENV{VERSION}<\/Version>/' \
    "<Version>$VERSION</Version>"

replace visualbasic/Wildling.vb \
    's/Version As String = "[^"]+"/Version As String = "$ENV{VERSION}"/' \
    "Version As String = \"$VERSION\""

replace visualbasic/Wildling.vbproj \
    's/<Version>[^<]+<\/Version>/<Version>$ENV{VERSION}<\/Version>/' \
    "<Version>$VERSION</Version>"

replace fsharp/Wildling.fs \
    's/Version = "[^"]+"/Version = "$ENV{VERSION}"/' \
    "Version = \"$VERSION\""

replace fsharp/Wildling.fsproj \
    's/<Version>[^<]+<\/Version>/<Version>$ENV{VERSION}<\/Version>/' \
    "<Version>$VERSION</Version>"

replace cpp/src/wildling.hpp \
    's/kVersion = "[^"]+"/kVersion = "$ENV{VERSION}"/' \
    "kVersion = \"$VERSION\""

replace php/src/Wildling.php \
    "s/VERSION = '[^']+'/VERSION = '\$ENV{VERSION}'/" \
    "VERSION = '$VERSION'"

replace c/src/wildling.h \
    's/WILDLING_VERSION "[^"]+"/WILDLING_VERSION "$ENV{VERSION}"/' \
    "WILDLING_VERSION \"$VERSION\""

replace go/wildling/wildling.go \
    's/Version = "[^"]+"/Version = "$ENV{VERSION}"/' \
    "Version = \"$VERSION\""

replace rust/src/wildling.rs \
    's/VERSION: &str = "[^"]+"/VERSION: \&str = "$ENV{VERSION}"/' \
    "VERSION: &str = \"$VERSION\""

replace rust/Cargo.toml \
    's/^version = "[^"]+"/version = "$ENV{VERSION}"/' \
    "version = \"$VERSION\""

# Cargo.lock: only the root package stanza (first occurrence of name = "wildling")
if [ "$CHECK" -eq 1 ]; then
    check_contains rust/Cargo.lock "version = \"$VERSION\""
else
    if [ -f rust/Cargo.lock ]; then
        VERSION="$VERSION" perl -i -0pe 's/(name = "wildling"\nversion = ")[^"]+"/${1}$ENV{VERSION}"/' rust/Cargo.lock
    fi
fi

replace kotlin/src/wildling/Wildling.kt \
    's/VERSION: String = "[^"]+"/VERSION: String = "$ENV{VERSION}"/' \
    "VERSION: String = \"$VERSION\""

replace ruby/lib/wildling/wildling.rb \
    's/VERSION = "[^"]+"/VERSION = "$ENV{VERSION}"/' \
    "VERSION = \"$VERSION\""

replace swift/Sources/Wildling.swift \
    's/version = "[^"]+"/version = "$ENV{VERSION}"/' \
    "version = \"$VERSION\""

replace scala/src/wildling/Wildling.scala \
    's/Version: String = "[^"]+"/Version: String = "$ENV{VERSION}"/' \
    "Version: String = \"$VERSION\""

replace dart/lib/src/wildling.dart \
    "s/version = '[^']+'/version = '\$ENV{VERSION}'/" \
    "version = '$VERSION'"

replace dart/pubspec.yaml \
    's/^version:\s*.*/version: $ENV{VERSION}/' \
    "version: $VERSION"

# pub.dev rejects publish when CHANGELOG omits the current version.
if [ "$CHECK" -eq 1 ]; then
    check_contains dart/CHANGELOG.md "## $VERSION"
elif [ -f dart/CHANGELOG.md ]; then
    if ! grep -Fq "## $VERSION" dart/CHANGELOG.md; then
        VERSION="$VERSION" perl -i -0pe \
            's/(All notable changes[^\n]*\n\n)/$1## $ENV{VERSION}\n\n- See [GitHub Releases](https:\/\/github.com\/dotmonk\/wildling\/releases)\n\n/s' \
            dart/CHANGELOG.md
    fi
fi

replace posix-shell/lib/wildling.sh \
    's/WILDLING_VERSION="[^"]+"/WILDLING_VERSION="$ENV{VERSION}"/' \
    "WILDLING_VERSION=\"$VERSION\""

replace powershell/lib/Wildling.ps1 \
    "s/WildlingVersion = '[^']+'/WildlingVersion = '\$ENV{VERSION}'/" \
    "WildlingVersion = '$VERSION'"

replace lua/lib/wildling/init.lua \
    's/M\.VERSION = "[^"]+"/M.VERSION = "$ENV{VERSION}"/' \
    "M.VERSION = \"$VERSION\""

replace assembly/src/cli.asm \
    's/version_str:\s*db "[^"]+"/version_str:            db "$ENV{VERSION}"/' \
    "db \"$VERSION\""

replace r/R/wildling.R \
    's/WILDLING_VERSION <- "[^"]+"/WILDLING_VERSION <- "$ENV{VERSION}"/' \
    "WILDLING_VERSION <- \"$VERSION\""

replace groovy/lib/wildling/wildling.groovy \
    's/VERSION = "[^"]+"/VERSION = "$ENV{VERSION}"/' \
    "VERSION = \"$VERSION\""

replace perl/lib/Wildling.pm \
    "s/\\\$VERSION = '[^']+'/\\\$VERSION = '\$ENV{VERSION}'/" \
    "\$VERSION = '$VERSION'"

replace elixir/lib/wildling.ex \
    's/\@version "[^"]+"/\@version "$ENV{VERSION}"/' \
    "@version \"$VERSION\""

replace pascal/src/wildlinglib.pas \
    "s/WILDLING_VERSION = '[^']+'/WILDLING_VERSION = '\$ENV{VERSION}'/" \
    "WILDLING_VERSION = '$VERSION'"

replace zig/src/wildling.zig \
    's/VERSION = "[^"]+"/VERSION = "$ENV{VERSION}"/' \
    "VERSION = \"$VERSION\""

replace fortran/src/wildling.f90 \
    "s/WILDLING_VERSION = '[^']+'/WILDLING_VERSION = '\$ENV{VERSION}'/" \
    "WILDLING_VERSION = '$VERSION'"

replace ada/src/wildling.ads \
    's/WILDLING_VERSION : constant String := "[^"]+"/WILDLING_VERSION : constant String := "$ENV{VERSION}"/' \
    "WILDLING_VERSION : constant String := \"$VERSION\""

replace haskell/src/Wildling.hs \
    's/^version = "[^"]+"/version = "$ENV{VERSION}"/' \
    "version = \"$VERSION\""

# Optional packaging metadata (created by publish waves); sync when present.
sync_optional() {
    _file="$1"
    _expr="$2"
    _expect="$3"
    if [ ! -f "$_file" ]; then
        return
    fi
    replace "$_file" "$_expr" "$_expect"
}

sync_optional elixir/mix.exs \
    's/version:\s*"[^"]+"/version: "$ENV{VERSION}"/' \
    "version: \"$VERSION\""

# LuaRocks requires filename package-version-revision.rockspec
lua_rockspec=""
for _cand in "lua/wildling-${VERSION}-1.rockspec" lua/wildling-*-*.rockspec lua/wildling.rockspec; do
    # Expand globs carefully
    for _f in $_cand; do
        if [ -f "$_f" ]; then
            lua_rockspec="$_f"
            break 2
        fi
    done
done
if [ -n "$lua_rockspec" ]; then
    if [ "$CHECK" -eq 1 ]; then
        check_contains "$lua_rockspec" "version = \"$VERSION-1\""
        if [ "$lua_rockspec" != "lua/wildling-${VERSION}-1.rockspec" ]; then
            echo "DRIFT $lua_rockspec (expected filename lua/wildling-${VERSION}-1.rockspec)" >&2
            fail=1
        fi
    else
        VERSION="$VERSION" perl -i -pe \
            's/version\s*=\s*"[^"]+"/version = "$ENV{VERSION}-1"/; s/tag\s*=\s*"[^"]+"/tag = "v$ENV{VERSION}"/' \
            "$lua_rockspec"
        if [ "$lua_rockspec" != "lua/wildling-${VERSION}-1.rockspec" ]; then
            mv "$lua_rockspec" "lua/wildling-${VERSION}-1.rockspec"
        fi
    fi
fi

sync_optional powershell/Wildling.psd1 \
    "s/ModuleVersion\s*=\s*'[^']+'/ModuleVersion = '\$ENV{VERSION}'/" \
    "ModuleVersion = '$VERSION'"

sync_optional zig/build.zig.zon \
    's/\.version\s*=\s*"[^"]+"/.version = "$ENV{VERSION}"/' \
    ".version = \"$VERSION\""

sync_optional haskell/wildling.cabal \
    's/^version:\s*.*/version:              $ENV{VERSION}/' \
    "version:              $VERSION"

sync_optional r/DESCRIPTION \
    's/^Version:\s*.*/Version: $ENV{VERSION}/' \
    "Version: $VERSION"

sync_optional fortran/fpm.toml \
    's/^version\s*=\s*"[^"]+"/version = "$ENV{VERSION}"/' \
    "version = \"$VERSION\""

sync_optional_slurp() {
    _file="$1"
    _expr="$2"
    if [ ! -f "$_file" ]; then
        return
    fi
    if [ "$CHECK" -eq 1 ]; then
        checked=$((checked + 1))
        if ! VERSION="$VERSION" perl -0ne 'exit(/<!-- WILDLING_PROJECT_VERSION -->\s*<version>\Q$ENV{VERSION}\E<\/version>/ ? 0 : 1)' "$_file"; then
            echo "DRIFT $_file (project version != $VERSION)" >&2
            fail=1
        fi
        return
    fi
    VERSION="$VERSION" perl -i -0pe "$_expr" "$_file"
}

sync_optional_slurp java/pom.xml \
    's/(<!-- WILDLING_PROJECT_VERSION -->\s*<version>)[^<]+(<\/version>)/${1}$ENV{VERSION}${2}/'
sync_optional_slurp kotlin/pom.xml \
    's/(<!-- WILDLING_PROJECT_VERSION -->\s*<version>)[^<]+(<\/version>)/${1}$ENV{VERSION}${2}/'
sync_optional_slurp scala/pom.xml \
    's/(<!-- WILDLING_PROJECT_VERSION -->\s*<version>)[^<]+(<\/version>)/${1}$ENV{VERSION}${2}/'
sync_optional_slurp groovy/pom.xml \
    's/(<!-- WILDLING_PROJECT_VERSION -->\s*<version>)[^<]+(<\/version>)/${1}$ENV{VERSION}${2}/'
if [ "$CHECK" -eq 1 ]; then
    if [ "$fail" -ne 0 ]; then
        echo "Version check failed against VERSION=$VERSION" >&2
        exit 1
    fi
    echo "OK: $checked locations match VERSION=$VERSION"
    exit 0
fi

if [ "$fail" -ne 0 ]; then
    echo "sync-version: some targets were missing" >&2
    exit 1
fi

echo "Synced VERSION=$VERSION into language ports"
