# wildling (PHP)

PHP library and CLI for pattern-based string generation. **Zero Composer dependencies** (PHP standard library only). Requires PHP 8.1+.

## Install

From this repository:

```bash
cd php
./build.sh
./bin/wildling "foo#"
```

Packagist (after the package is submitted — see [`docs/publishing.md`](../docs/publishing.md)):

```bash
composer require dotmonk/wildling
```

Packagist uses the **repository root** [`composer.json`](../composer.json) (paths into `php/`). Submit only:

`https://github.com/dotmonk/wildling`

Do not use a `/php` URL — that is not a separate Git repo.

For local path development inside this monorepo:

```json
{
  "repositories": [
    {
      "type": "path",
      "url": "./php"
    }
  ],
  "require": {
    "dotmonk/wildling": "*"
  }
}
```

As a library:

```php
<?php
require 'vendor/autoload.php';

use Wildling\Wildling;

$wildling = Wildling::create(['foo#']);
$value = $wildling->next();
while ($value !== false) {
    echo $value, "\n";
    $value = $wildling->next();
}
```

## CLI

```bash
./bin/wildling "foo#"
./bin/wildling --dictionary planets:../dictionaries/planets.txt "%{'planets'}"
./bin/wildling --template ./config.json
```

The launcher uses local `php` when available, otherwise Docker (`php:8.3-cli-alpine`).

Help text and `--check` output follow [`docs/cli.md`](../docs/cli.md) / [`docs/help.txt`](../docs/help.txt).

## Build

```bash
./build.sh   # Docker: copy help.txt + php -l syntax check
```

Project tests live in `../tests/` and are run with `../test.sh`.
