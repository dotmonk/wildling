# wildling (Perl)

Perl library and CLI for pattern-based string generation. **Zero CPAN dependencies** (core Perl only — hand-rolled JSON). Requires Perl 5.14+.

## Install

From this repository:

```bash
cd perl
./build.sh
./bin/wildling "foo#"
```

```perl
use lib './lib';
use Wildling;

my $wildling = Wildling::create(['foo#']);
my $value = $wildling->next();
while (!Wildling::is_false($value)) {
    print "$value\n";
    $value = $wildling->next();
}
```

## CLI

```bash
./bin/wildling "foo#"
./bin/wildling --dictionary planets:../dictionaries/planets.txt "%{'planets'}"
./bin/wildling --template ./config.json
```

Help text and `--check` output follow [`docs/cli.md`](../docs/cli.md) / [`docs/help.txt`](../docs/help.txt).

## Build

```bash
./build.sh   # Docker (python:3.13-alpine + perl): copy help.txt + perl -c syntax check
```

Project tests live in `../tests/` and are run with `../test.sh`.
