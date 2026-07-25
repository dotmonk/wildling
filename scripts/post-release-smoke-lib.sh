#!/bin/sh
# Shared helpers for post-release consumer smoke.
# Sourced by scripts/post-release-smoke.sh and <lang>/post-release-smoke.sh
# shellcheck shell=sh

post_release_smoke_init() {
    # Caller should set ROOT; fall back when sourced awkwardly.
    if [ -z "${ROOT:-}" ]; then
        ROOT="$(cd "$(dirname "$0")/.." && pwd)"
    fi

    REPO_URL="${REPO_URL:-${WILDLING_SMOKE_REPO:-https://github.com/dotmonk/wildling.git}}"
    REPO_SLUG="${REPO_SLUG:-${GITHUB_REPOSITORY:-dotmonk/wildling}}"
    GO_MOD="${GO_MOD:-github.com/dotmonk/wildling/go/v2}"

    if [ -z "${TAG:-}" ]; then
        TAG="$(post_release_smoke_resolve_tag)"
    fi
    VERSION="${VERSION:-${TAG#v}}"

    if [ -z "${SMOKE_ROOT:-}" ]; then
        if [ -n "${WILDLING_SMOKE_WORKDIR:-}" ]; then
            SMOKE_ROOT="$WILDLING_SMOKE_WORKDIR"
            mkdir -p "$SMOKE_ROOT"
        else
            SMOKE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/wildling-post-smoke.XXXXXX")"
        fi
    fi

    export ROOT REPO_URL REPO_SLUG GO_MOD TAG VERSION SMOKE_ROOT
}

post_release_smoke_resolve_tag() {
    if [ -n "${WILDLING_SMOKE_TAG:-}" ]; then
        echo "$WILDLING_SMOKE_TAG"
        return
    fi
    if command -v gh >/dev/null 2>&1; then
        _t="$(gh api "repos/${REPO_SLUG:-dotmonk/wildling}/releases/latest" --jq .tag_name 2>/dev/null || true)"
        if [ -n "$_t" ] && [ "$_t" != "null" ]; then
            echo "$_t"
            return
        fi
    fi
    echo "v$(tr -d '[:space:]' < "${ROOT}/VERSION")"
}

docker_pull() {
    _image="$1"
    _attempt=1
    while [ "${_attempt}" -le 3 ]; do
        if docker pull "${_image}"; then
            return 0
        fi
        echo "docker pull failed for ${_image} (attempt ${_attempt}/3); retrying…" >&2
        _attempt=$((_attempt + 1))
        sleep $((_attempt * 2))
    done
    echo "docker pull failed for ${_image}" >&2
    return 1
}

# run_docker IMAGE WORKDIR_ON_HOST CMD [extra docker args...]
run_docker() {
    _image="$1"
    _workdir="$2"
    _cmd="$3"
    shift 3
    docker_pull "${_image}" || return 1
    docker run --rm \
        -v "${_workdir}:/work" \
        -w /work \
        --network=host \
        --user "$(id -u):$(id -g)" \
        -e HOME=/tmp \
        -e "WILDLING_VERSION=${VERSION}" \
        -e "WILDLING_TAG=${TAG}" \
        "$@" \
        "${_image}" \
        sh -c "${_cmd}"
}

run_docker_root() {
    _image="$1"
    _workdir="$2"
    _cmd="$3"
    shift 3
    docker_pull "${_image}" || return 1
    docker run --rm \
        -v "${_workdir}:/work" \
        -w /work \
        --network=host \
        -e HOME=/tmp \
        -e "WILDLING_VERSION=${VERSION}" \
        -e "WILDLING_TAG=${TAG}" \
        "$@" \
        "${_image}" \
        sh -c "${_cmd}"
}

EXPECTED_CHECK=$(cat <<'EOF'
patterns: ab
dictionaries:
select:
range:
total: 1
generator: ab 1
EOF
)

assert_cli() {
    _cli="$1"
    _label="${2:-cli}"
    echo "    assert CLI (${_label}): ${_cli}"

    _ver_out="$("${_cli}" --version 2>/dev/null || "${_cli}" -v 2>/dev/null || true)"
    case " ${_ver_out} " in
        *" ${VERSION} "*|*"${VERSION}"*) ;;
        *)
            echo "FAIL: ${_label}: --version missing ${VERSION} (got: ${_ver_out})" >&2
            return 1
            ;;
    esac

    _out="$("${_cli}" "ab")"
    if [ "${_out}" != "ab" ]; then
        echo "FAIL: ${_label}: pattern ab => expected 'ab', got '${_out}'" >&2
        return 1
    fi

    _check="$("${_cli}" --check "ab")"
    if [ "${_check}" != "${EXPECTED_CHECK}" ]; then
        echo "FAIL: ${_label}: --check output mismatch" >&2
        echo "got:" >&2
        printf '%s\n' "${_check}" >&2
        echo "expected:" >&2
        printf '%s\n' "${EXPECTED_CHECK}" >&2
        return 1
    fi
    return 0
}

# channel LANG NAME CMD...
# Uses SMOKE_FAIL (integer) in the calling script.
channel() {
    _lang="$1"
    _channel="$2"
    shift 2
    echo "==> ${_lang} / ${_channel}"
    if ! "$@"; then
        echo "FAIL: ${_lang} / ${_channel}" >&2
        SMOKE_FAIL=$((SMOKE_FAIL + 1))
        return 0
    fi
    echo "OK: ${_lang} / ${_channel}"
}

workdir() {
    _name="$1"
    _d="${SMOKE_ROOT}/${_name}"
    rm -rf "${_d}"
    mkdir -p "${_d}"
    echo "${_d}"
}

clone_tag() {
    _dest="$1"
    git clone --branch "${TAG}" --depth 1 "${REPO_URL}" "${_dest}"
}

# Clone tag, build one language via monorepo build.sh, assert CLI.
smoke_clone_build_cli() {
    _lang="$1"
    _wd="$(workdir "${_lang}-git")"
    clone_tag "${_wd}/repo"
    (cd "${_wd}/repo" && ./build.sh "${_lang}")
    assert_cli "${_wd}/repo/${_lang}/bin/wildling" "${_lang}-git"
}
