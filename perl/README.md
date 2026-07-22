# wildling (Perl)

Perl library and CLI for pattern-based string generation. **Zero CPAN dependencies** (core Perl only — hand-rolled JSON). Requires Perl 5.14+.

## Install

From this repository:

```bash
cd perl
./build.sh
./bin/wildling "foo#"
```

From a release tag:

```bash
git clone --branch v2.0.0 --depth 1 https://github.com/dotmonk/wildling.git
cd wildling
./build.sh perl
```

```perl
use lib './lib';
use Wildling;

my $wildling = Wildling::create(['foo#']);
while (defined(my $value = $wildling->next())) {
    print "$value\n";
}
# get()/next() return undef when out of range (not the string "false").
# Empty combinations are defined "" — distinct from the sentinel.
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
