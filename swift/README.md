# wildling (Swift)

Swift library and CLI for pattern-based string generation. **Zero third-party packages** (Foundation / Swift standard library only). Targets Swift 5.9+ / 6.x on Linux or macOS.

## Install

From this repository:

```bash
cd swift
./build.sh
./bin/wildling "foo#"
```

Produces `dist/wildling`. As a library, compile the `Sources/` files (excluding `main.swift`) into your target.

```swift
let wildling = Wildling(patterns: ["foo#"])
while let value = wildling.next() {
    print(value)
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
./build.sh   # Docker (swift:6.0-bookworm): swiftc -static-stdlib → dist/wildling
```

Project tests live in `../tests/` and are run with `../test.sh`.
