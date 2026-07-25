#!/bin/sh
# Post-release consumer smoke for php (git/GitHub + registry as documented).
set -eu

LANG_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$LANG_DIR/.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/scripts/post-release-smoke-lib.sh"
post_release_smoke_init

SMOKE_FAIL=0

smoke_php() {
    channel php git smoke_php_git
    channel php registry smoke_php_registry
}

smoke_php_git() {
    _wd="$(workdir php-git)"
    clone_tag "${_wd}/repo"
    run_docker_root "composer:2" "${_wd}" '
set -eu
git config --global --add safe.directory /work/repo
mkdir -p app && cd app
cat > composer.json <<EOF
{
  "repositories": [{
    "type": "path",
    "url": "/work/repo/php",
    "options": { "versions": { "dotmonk/wildling": "'"${VERSION}"'" } }
  }],
  "require": { "dotmonk/wildling": "'"${VERSION}"'" }
}
EOF
composer update --no-interaction
php -r "
require \"vendor/autoload.php\";
use Wildling\\Wildling;
\$w = Wildling::create([\"ab\"]);
if (\$w->count() !== 1) exit(1);
if (\$w->get(0) !== \"ab\") exit(2);
"
php vendor/dotmonk/wildling/bin/wildling.php --version | grep -F "'"${VERSION}"'"
[ "$(php vendor/dotmonk/wildling/bin/wildling.php ab)" = ab ]
'
}

smoke_php_registry() {
    _wd="$(workdir php-registry)"
    run_docker_root "composer:2" "${_wd}" '
set -eu
mkdir -p app && cd app
composer require --no-interaction "dotmonk/wildling:'"${VERSION}"'"
php -r "
require \"vendor/autoload.php\";
use Wildling\\Wildling;
\$w = Wildling::create([\"ab\"]);
if (\$w->count() !== 1) exit(1);
if (\$w->get(0) !== \"ab\") exit(2);
"
php vendor/dotmonk/wildling/bin/wildling.php --version | grep -F "'"${VERSION}"'"
[ "$(php vendor/dotmonk/wildling/bin/wildling.php ab)" = ab ]
'
}

smoke_php

if [ "$SMOKE_FAIL" -ne 0 ]; then
    echo "Post-release smoke failed for php." >&2
    exit 1
fi
