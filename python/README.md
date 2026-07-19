# wildling (Python)

Python library and CLI for pattern-based string generation. **Zero third-party dependencies** (stdlib only). Requires Python 3.9+.

## Install

From this repository:

```bash
cd python
./build.sh
# or without Docker:
cp ../docs/help.txt wildling/help.txt
```

The CLI is `./bin/wildling`.

```bash
pip install "git+https://github.com/dotmonk/wildling.git#subdirectory=python"
```

## Library

```python
from wildling import create_wildling

wildling = create_wildling(
    patterns=["abrakadabra", "foo#"],
    dictionaries={"colors": ["red", "blue"]},
)

wildling.count()  # 11
wildling.get(0)   # "abrakadabra"

value = wildling.next()
while value is not False:
    print(value)
    value = wildling.next()

wildling.reset()
```

### API

| Method | Description |
|--------|-------------|
| `next()` | Next combination, or `False` when exhausted |
| `get(index)` | Combination at `index`, or `False` if out of range |
| `count()` | Total combinations across all patterns |
| `index()` | Current position (after `next` calls) |
| `reset()` | Reset iteration to the start |
| `generators()` | Per-pattern generators |

## CLI

```bash
./bin/wildling "foo#"
./bin/wildling --dictionary planets:../dictionaries/planets.txt "%{'planets'}"
./bin/wildling --template ./config.json
```

Help text and `--check` output follow [`docs/cli.md`](../docs/cli.md) / [`docs/help.txt`](../docs/help.txt).

## Build

```bash
./build.sh   # Docker: copy help.txt + byte-compile
```

Project tests live in `../tests/` and are run with `../test.sh`.
