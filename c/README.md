# wildling (C)

C library and CLI for pattern-based string generation. **Zero third-party libraries** — C11 + POSIX `regex.h` (for pattern splitting) and a minimal JSON parser for `--template`.

## Install

From this repository:

```bash
cd c
./build.sh
./bin/wildling "foo#"
```

From a release tag:

```bash
git clone --branch v2.0.0 --depth 1 https://github.com/dotmonk/wildling.git
cd wildling
./build.sh c
```

Produces `dist/wildling`. Link the sources under `src/` (except `cli.c`) to use as a library.

## CLI

```bash
./bin/wildling "foo#"
./bin/wildling --dictionary planets:../dictionaries/planets.txt "%{'planets'}"
./bin/wildling --template ./config.json
```

Help text and `--check` output follow [`docs/cli.md`](../docs/cli.md) / [`docs/help.txt`](../docs/help.txt).

## Build

```bash
./build.sh   # Docker (gcc:14-bookworm): gcc -std=c11 → dist/wildling
```

Project tests live in `../tests/` and are run with `../test.sh`.
