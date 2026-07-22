# wildling (JavaScript)

TypeScript library and CLI for pattern-based string generation. Runtime has **zero npm dependencies** (Node.js only); TypeScript is a build-time devDependency.

## Install

**Registry:**

```bash
npm install wildling
```

**Git (monorepo subdirectory):**

```bash
npm install "git+https://github.com/dotmonk/wildling.git#v2.0.0:javascript"
```

`prepare` builds `dist/` when missing (Node 18+, network for TypeScript on first install).

In `package.json`:

```json
"wildling": "github:dotmonk/wildling#v2.0.0:javascript"
```

From this repository:

```bash
cd javascript
npm ci --include=dev
npm run build
```

The CLI is `./bin/wildling`. The library entry is `dist/index.js`.

## Library

```js
const createWildling = require("wildling").default;
// or: import createWildling from "wildling";

const wildling = createWildling({
  patterns: ["abrakadabra", "foo#"],
  dictionaries: {
    colors: ["red", "blue"],
  },
});

wildling.count(); // 11
wildling.get(0); // "abrakadabra"

let value;
while ((value = wildling.next())) {
  console.log(value);
}

wildling.reset();
```

### Options

| Field | Type | Description |
|-------|------|-------------|
| `patterns` | `string[]` | One or more patterns to expand |
| `dictionaries` | `{ [name: string]: string[] }` | Named word lists for `%{'name'}` |

### API

| Method | Description |
|--------|-------------|
| `next()` | Next combination, or `false` when exhausted |
| `get(index)` | Combination at `index`, or `false` if out of range |
| `count()` | Total combinations across all patterns |
| `index()` | Current position (after `next` calls) |
| `reset()` | Reset iteration to the start |
| `generators()` | Per-pattern generators |

## CLI

```bash
wildling [options] [pattern ...]
```

| Option | Description |
|--------|-------------|
| `--select #` | Print only combination `#` (repeatable) |
| `--range #-#` | Print combinations from `#` to `#` inclusive (repeatable) |
| `--check` | Print generation info instead of results |
| `--dictionary <name>:<path>` | Load a dictionary file as `<name>` (repeatable) |
| `--template <path>` | Load options from a JSON template |
| `--help`, `-h` | Help (shared text from `docs/help.txt`) |
| `--version`, `-v` | Version |

`--check` and help text follow the cross-language contracts in [`docs/cli.md`](../docs/cli.md).

Examples:

```bash
./bin/wildling "foo#"
./bin/wildling --dictionary planets:../dictionaries/planets.txt "%{'planets'}"
./bin/wildling --select 0 --range 8-9 "##"
./bin/wildling --template ./config.json
```

### Template JSON

```json
{
  "patterns": ["foo#", "%{'colors'}"],
  "dictionaries": {
    "colors": "path/to/colors.txt",
    "inline": ["red", "blue"]
  },
  "select": [0, 2],
  "range": ["5-7"],
  "check": false
}
```

Dictionary values may be a file path or an inline string array. Template fields merge with CLI flags in argument order.

## Patterns

### Simple wildcards

| Token | Alphabet |
|-------|----------|
| `#` | `0-9` |
| `@` | `a-z` |
| `*` | `a-z` and `0-9` |
| `&` | `a-zA-Z` |
| `!` | `A-Z` |
| `?` | `A-Z` and `0-9` |
| `-` | `a-zA-Z0-9` |

Optional length: `#{2}`, `@{1-2}`, `*{1-2}` (start–end inclusive).

### Special wildcards

```text
${'blue,red,green',1-2}   words / punctuation from a list
%{'colors'}               dictionary named "colors"
%{'colors',1-2}           dictionary with length range
```

Escape a wildcard with a backslash: `\##` → `#0` … `#9`.

## Build

```bash
npm run build
# or from repo root: ./build.sh  (Docker)
```

Project tests live in `../tests/` and are run with `../test.sh`.
