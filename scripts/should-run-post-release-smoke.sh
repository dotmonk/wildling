#!/bin/sh
# Decide whether post-release smoke should run (CI gate).
#
# Post-release: latest GitHub Release is between 24h10m and 25h10m old
#   (one hourly cron tick after the delay).
# Daily: latest release is >= 48h old and UTC hour is 3 (cron at :10 → 03:10).
#
# Env:
#   FORCE=1|true          Always run (workflow_dispatch)
#   TAG_OVERRIDE=vX.Y.Z   Pin tag (still applies age checks unless FORCE)
#   GITHUB_REPOSITORY     owner/repo (default dotmonk/wildling)
#   GITHUB_OUTPUT         If set, write should_run/reason/tag for Actions
#
# Prints: should_run=<bool> reason=<...> tag=<vX.Y.Z>
set -eu

REPO="${GITHUB_REPOSITORY:-dotmonk/wildling}"
FORCE="${FORCE:-0}"
TAG_OVERRIDE="${TAG_OVERRIDE:-}"

set_output() {
    _k="$1"
    _v="$2"
    echo "${_k}=${_v}"
    if [ -n "${GITHUB_OUTPUT:-}" ]; then
        echo "${_k}=${_v}" >> "$GITHUB_OUTPUT"
    fi
}

case "$FORCE" in
    1|true|TRUE|yes|YES) FORCE=1 ;;
    *) FORCE=0 ;;
esac

if [ -n "$TAG_OVERRIDE" ]; then
    TAG="$TAG_OVERRIDE"
    # Still need published_at for age unless forcing.
    PUBLISHED_AT="$(gh api "repos/${REPO}/releases/tags/${TAG}" --jq .published_at 2>/dev/null || true)"
    if [ -z "$PUBLISHED_AT" ] && [ "$FORCE" -eq 0 ]; then
        set_output should_run false
        set_output reason "no-release"
        set_output tag "$TAG"
        exit 0
    fi
else
    JSON="$(gh api "repos/${REPO}/releases/latest" 2>/dev/null || true)"
    if [ -z "$JSON" ]; then
        set_output should_run false
        set_output reason "no-release"
        set_output tag ""
        exit 0
    fi
    TAG="$(printf '%s' "$JSON" | jq -r .tag_name)"
    PUBLISHED_AT="$(printf '%s' "$JSON" | jq -r .published_at)"
fi

if [ "$FORCE" -eq 1 ]; then
    set_output should_run true
    set_output reason force
    set_output tag "$TAG"
    exit 0
fi

# Epoch seconds (GNU date on Actions ubuntu; also accept busybox).
published_epoch="$(date -u -d "$PUBLISHED_AT" +%s 2>/dev/null || date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "$PUBLISHED_AT" +%s)"
now_epoch="$(date -u +%s)"
age=$((now_epoch - published_epoch))
utc_hour="$(date -u +%H)"
# strip leading zero for decimal arithmetic
utc_hour=$((utc_hour + 0))

POST_MIN=$((24 * 3600 + 10 * 60))   # 24h10m
POST_MAX=$((25 * 3600 + 10 * 60))   # 25h10m
STALE=$((48 * 3600))

if [ "$age" -ge "$POST_MIN" ] && [ "$age" -lt "$POST_MAX" ]; then
    set_output should_run true
    set_output reason post-release
    set_output tag "$TAG"
    exit 0
fi

if [ "$age" -ge "$STALE" ] && [ "$utc_hour" -eq 3 ]; then
    set_output should_run true
    set_output reason daily
    set_output tag "$TAG"
    exit 0
fi

set_output should_run false
set_output reason skip
set_output tag "$TAG"
exit 0
