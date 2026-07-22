#!/bin/sh
# Shared helpers for ecosystem mirror scripts (sourced, not executed).
set -eu

mirror_ecosystem_root() {
    cd "$(dirname "$0")/.." && pwd
}

mirror_ecosystem_read_version() {
    tr -d '[:space:]' < "$(mirror_ecosystem_root)/VERSION"
}

# Push a prepared directory to an ecosystem mirror repo and tag it.
# Usage: mirror_ecosystem_push <workdir> <tag> <token> <owner/repo> <label>
mirror_ecosystem_push() {
    _workdir="$1"
    _tag="$2"
    _token="$3"
    _mirror_repo="$4"
    _label="$5"

    if [ -z "$_token" ]; then
        echo "Mirror token not set for ${_label}" >&2
        return 1
    fi

    cd "$_workdir"

    git init -b main
    git config user.name "wildling-release"
    git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
    git add -A
    git commit -m "Sync from dotmonk/wildling ${_tag} (${_label})"

    _remote="https://x-access-token:${_token}@github.com/${_mirror_repo}.git"
    git remote add origin "$_remote"
    git push -f origin main
    git tag -f "$_tag" -m "wildling ${_label} ${_tag}"
    git push -f origin "$_tag"

    echo "Mirrored ${_label} to ${_mirror_repo} @ ${_tag}"
}

# Copy MIT license into mirror tree when present.
mirror_ecosystem_copy_license() {
    _dest="$1"
    _root="$(mirror_ecosystem_root)"
    if [ -f "$_root/LICENSE" ]; then
        cp "$_root/LICENSE" "$_dest/LICENSE"
    fi
}
