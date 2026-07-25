#!/bin/sh
# Post-release consumer smoke for elixir (git/GitHub + registry as documented).
set -eu

LANG_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$LANG_DIR/.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/scripts/post-release-smoke-lib.sh"
post_release_smoke_init

SMOKE_FAIL=0

smoke_elixir() {
    channel elixir git smoke_elixir_git
    channel elixir registry smoke_elixir_registry
}

smoke_elixir_git() {
    _wd="$(workdir elixir-git)"
    run_docker_root "elixir:1.17-otp-27" "${_wd}" '
set -eu
mix local.hex --force >/dev/null
mix local.rebar --force >/dev/null
mkdir -p smoke/lib && cd smoke
cat > mix.exs <<EOF
defmodule Smoke.MixProject do
  use Mix.Project
  def project do
    [
      app: :smoke,
      version: "0.1.0",
      elixir: "~> 1.15",
      deps: [
        {:wildling, git: "https://github.com/dotmonk/wildling.git", tag: "'"${TAG}"'", sparse: "elixir"}
      ]
    ]
  end
  def application, do: []
end
EOF
# Hex-style path key is "sparse" in newer mix; fall back to path form via clone if needed
set +e
mix deps.get
status=$?
set -e
if [ "$status" -ne 0 ]; then
  cd /work
  git clone --branch "'"${TAG}"'" --depth 1 https://github.com/dotmonk/wildling.git repo
  cd smoke
  cat > mix.exs <<EOF
defmodule Smoke.MixProject do
  use Mix.Project
  def project do
    [
      app: :smoke,
      version: "0.1.0",
      elixir: "~> 1.15",
      deps: [
        {:wildling, path: "/work/repo/elixir"}
      ]
    ]
  end
  def application, do: []
end
EOF
  mix deps.get
fi
mix deps.compile
cat > lib/smoke.ex <<EOF
defmodule Smoke do
  def main do
    w = Wildling.create(["ab"])
    1 = Wildling.count(w)
    "ab" = Wildling.get(w, 0)
    IO.puts("ok")
  end
end
EOF
mix run -e "Smoke.main()" | grep -q ok
'
}

smoke_elixir_registry() {
    _wd="$(workdir elixir-registry)"
    run_docker_root "elixir:1.17-otp-27" "${_wd}" '
set -eu
mix local.hex --force >/dev/null
mix local.rebar --force >/dev/null
mkdir -p smoke/lib && cd smoke
cat > mix.exs <<EOF
defmodule Smoke.MixProject do
  use Mix.Project
  def project do
    [
      app: :smoke,
      version: "0.1.0",
      elixir: "~> 1.15",
      deps: [{:wildling, "'"${VERSION}"'"}]
    ]
  end
  def application, do: []
end
EOF
mix deps.get
mix deps.compile
cat > lib/smoke.ex <<EOF
defmodule Smoke do
  def main do
    w = Wildling.create(["ab"])
    1 = Wildling.count(w)
    "ab" = Wildling.get(w, 0)
    IO.puts("ok")
  end
end
EOF
mix run -e "Smoke.main()" | grep -q ok
'
}

smoke_elixir

if [ "$SMOKE_FAIL" -ne 0 ]; then
    echo "Post-release smoke failed for elixir." >&2
    exit 1
fi
