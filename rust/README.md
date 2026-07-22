# wildling (Rust)

Rust library and CLI for pattern-based string generation. **Zero crates.io dependencies** (Rust standard library only). Pattern splitting and JSON parsing are hand-rolled.

## Install

From this repository:

```bash
cd rust
./build.sh
./bin/wildling "foo#"
```

**Git** (`Cargo.toml`):

```toml
wildling = { git = "https://github.com/dotmonk/wildling", tag = "v2.0.0", path = "rust" }
```

**Registry:** `cargo install wildling`

Or after clone: `cargo install --path .`

```rust
use wildling::{Dictionaries, Wildling};

let dicts = Dictionaries::new();
let mut w = Wildling::new(&["foo#".to_string()], &dicts);
while let Some(value) = w.next() {
    println!("{value}");
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
./build.sh   # Docker (rust:1.83): cargo build --release → dist/wildling
```

Project tests live in `../tests/` and are run with `../test.sh`.
