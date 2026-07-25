#!/bin/sh
# Post-release consumer smoke for ruby (git/GitHub + registry as documented).
set -eu

LANG_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$LANG_DIR/.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/scripts/post-release-smoke-lib.sh"
post_release_smoke_init

SMOKE_FAIL=0

smoke_ruby() {
    channel ruby git smoke_ruby_git
    channel ruby registry smoke_ruby_registry
}

smoke_ruby_git() {
    _wd="$(workdir ruby-git)"
    run_docker_root "ruby:3.3-alpine" "${_wd}" '
set -eu
apk add --no-cache git build-base >/dev/null
mkdir -p app && cd app
cat > Gemfile <<EOF
source "https://rubygems.org"
gem "wildling", git: "https://github.com/dotmonk/wildling.git", tag: "'"${TAG}"'", glob: "ruby/wildling.gemspec"
EOF
bundle install --quiet
bundle exec ruby -e "
require \"wildling\"
w = Wildling.create([\"ab\"])
raise \"count\" unless w.count == 1
raise \"get\" unless w.get(0) == \"ab\"
"
GEM_ROOT="$(bundle exec ruby -e "print Gem::Specification.find_by_name(\"wildling\").full_gem_path")"
if bundle exec wildling --version 2>/dev/null | grep -F "'"${VERSION}"'" >/dev/null; then
  [ "$(bundle exec wildling ab)" = ab ]
else
  bundle exec ruby "$GEM_ROOT/bin/wildling.rb" --version | grep -F "'"${VERSION}"'"
  [ "$(bundle exec ruby "$GEM_ROOT/bin/wildling.rb" ab)" = ab ]
fi
'
}

smoke_ruby_registry() {
    _wd="$(workdir ruby-registry)"
    run_docker_root "ruby:3.3-alpine" "${_wd}" '
set -eu
gem install wildling -v "'"${VERSION}"'" --no-document
ruby -e "
require \"wildling\"
w = Wildling.create([\"ab\"])
raise \"count\" unless w.count == 1
raise \"get\" unless w.get(0) == \"ab\"
"
# Prefer the gem binstub; fall back to wildling.rb for gems through 2.0.6 that
# shipped a shell script as the Rubygems executable.
if wildling --version 2>/dev/null | grep -F "'"${VERSION}"'" >/dev/null; then
  [ "$(wildling ab)" = ab ]
else
  GEM_ROOT="$(ruby -e "print Gem::Specification.find_by_name(\"wildling\").full_gem_path")"
  ruby "$GEM_ROOT/bin/wildling.rb" --version | grep -F "'"${VERSION}"'"
  [ "$(ruby "$GEM_ROOT/bin/wildling.rb" ab)" = ab ]
fi
'
}

smoke_ruby

if [ "$SMOKE_FAIL" -ne 0 ]; then
    echo "Post-release smoke failed for ruby." >&2
    exit 1
fi
