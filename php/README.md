# wildling (PHP)

PHP library and CLI for pattern-based string generation. **Zero Composer dependencies** (PHP standard library only). Requires PHP 8.1+.

## Install

From this repository:

```bash
cd php
./build.sh
./bin/wildling "foo#"
```

```bash
composer require dotmonk/wildling:dev-main
```

Or from GitHub:

```bash
composer config repositories.wildling vcs https://github.com/dotmonk/wildling.git
# then require with path / subdirectory as needed
```

As a library:

```php
<?php
require 'vendor/autoload.php'; // or php/bootstrap.php

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
