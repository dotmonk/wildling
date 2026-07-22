# wildling

PHP library and CLI for pattern-based string generation. **Zero Composer dependencies** (PHP standard library only). Requires PHP 8.1+.

<!-- wildling:preamble -->
**Docs:** [Website](https://dotmonk.github.io/wildling/) · [Sandbox](https://dotmonk.github.io/wildling/sandbox.html) · [Syntax](https://dotmonk.github.io/wildling/syntax.html) · [Source](https://github.com/dotmonk/wildling/tree/main/php)

**Registry:** [Packagist](https://packagist.org/packages/dotmonk/wildling)

## Example

```text
http://${'dev,stage,prod'}\-${'api,web'}#{0-2}.example.${'com,net,org'}/@.html
```

(The `\-` is a literal hyphen; bare `-` would mean “one letter or digit”. `@` is one lowercase letter.)

That builds **URL-shaped** candidates: scheme `http://`, then environment × service × optional digits × TLD, then a one-letter path page. Three environments, two services, zero–two digits (`''`, `0`–`9`, `00`–`99`), three TLDs, and `a`–`z` → **51948** strings — the kind of list you generate for fuzzing links or probing staging hosts, not type out.

A few of them:

- `http://dev-api.example.com/a.html` / `http://stage-web.example.com/z.html`
- `http://dev-api0.example.net/a.html` / `http://prod-web9.example.org/m.html`
- `http://dev-api00.example.com/a.html` / `http://prod-web99.example.org/z.html`

Named dictionaries (`%{'hosts'}`) work the same way when the word lists live in files.

Try it in the [sandbox](https://dotmonk.github.io/wildling/sandbox.html?pattern=http%3A%2F%2F%24%7B%27dev%2Cstage%2Cprod%27%7D%5C-%24%7B%27api%2Cweb%27%7D%23%7B0-2%7D.example.%24%7B%27com%2Cnet%2Corg%27%7D%2F%40.html), or see [pattern syntax](https://dotmonk.github.io/wildling/syntax.html) for length ranges, dictionaries, and escapes.
<!-- /wildling:preamble -->

## Install

From this repository:

```bash
cd php
./build.sh
./bin/wildling "Year 19##"
```

**Registry** (Packagist via [`dotmonk/wildling-php`](https://github.com/dotmonk/wildling-php)):

```bash
composer require dotmonk/wildling
```

**Path** (monorepo clone):

```json
{
  "repositories": [{ "type": "path", "url": "./php" }],
  "require": { "dotmonk/wildling": "*" }
}
```

As a library:

```php
<?php
require 'vendor/autoload.php';

use Wildling\Wildling;

$wildling = Wildling::create(['Year 19##']);
$value = $wildling->next();
while ($value !== false) {
    echo $value, "\n";
    $value = $wildling->next();
}
```

## CLI

```bash
./bin/wildling "Year 19##"
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
