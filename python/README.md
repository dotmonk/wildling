# wildling

Python library and CLI for pattern-based string generation. **Zero third-party dependencies** (stdlib only). Requires Python 3.9+.

<!-- wildling:preamble -->
**Docs:** [Website](https://dotmonk.github.io/wildling/) · [Sandbox](https://dotmonk.github.io/wildling/sandbox.html) · [Syntax](https://dotmonk.github.io/wildling/syntax.html) · [Source](https://github.com/dotmonk/wildling/tree/main/python)

**Registry:** [PyPI](https://pypi.org/project/wildling/)

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
cd python
./build.sh
# or without Docker:
cp ../docs/help.txt wildling/help.txt
```

The CLI is `./bin/wildling`.

**Registry:** `pip install wildling`

**Git:**

```bash
pip install "git+https://github.com/dotmonk/wildling.git@v2.0.4#subdirectory=python"
```

## Library

```python
from wildling import create_wildling

wildling = create_wildling(
    patterns=["abrakadabra", "Year 19##"],
    dictionaries={"colors": ["red", "blue"]},
)

wildling.count()  # 101
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
./bin/wildling "Year 19##"
./bin/wildling --dictionary planets:../dictionaries/planets.txt "%{'planets'}"
./bin/wildling --template ./config.json
```

Help text and `--check` output follow [`docs/cli.md`](../docs/cli.md) / [`docs/help.txt`](../docs/help.txt).

## Build

```bash
./build.sh   # Docker: copy help.txt + byte-compile
```

Project tests live in `../tests/` and are run with `../test.sh`.
