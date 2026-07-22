# wildling (POSIX shell)

Pattern-based string generator library and CLI using **POSIX sh + awk** only (no bashisms, no jq, no Python).

## Install

From this repository:

```bash
cd posix-shell
./build.sh
./bin/wildling "foo#"
```

From a release tag:

```bash
git clone --branch v2.0.0 --depth 1 https://github.com/dotmonk/wildling.git
cd wildling
./build.sh posix-shell
```

As a library:

```sh
. lib/wildling.sh
_wildling_parse_args "foo#"
_wildling_run_engine
```

Or use the programmatic helpers after sourcing `lib/wildling.sh`.

## CLI

```bash
./bin/wildling "foo#"
./bin/wildling --dictionary planets:../dictionaries/planets.txt "%{'planets'}"
./bin/wildling --template ./config.json
```

Help text and `--check` output follow [`docs/cli.md`](../docs/cli.md) / [`docs/help.txt`](../docs/help.txt).

## Build

```bash
./build.sh   # Docker: copy help.txt + sh -n syntax check
```

Project tests live in `../tests/` and are run with `../test.sh`.

## Stack

- **Shell**: POSIX sh (`#!/bin/sh`) for CLI and library wrapper
- **Awk**: POSIX awk for pattern parsing, token/generator engine, and template JSON parsing
- **Zero dependencies** outside sh and awk
