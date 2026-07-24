# wildling

TypeScript library and CLI for pattern-based string generation. Runtime has **zero npm dependencies** (Node.js only); TypeScript is a build-time devDependency.

<!-- wildling:preamble -->
**Docs:** [Website](https://dotmonk.github.io/wildling/) · [Sandbox](https://dotmonk.github.io/wildling/sandbox.html) · [Syntax](https://dotmonk.github.io/wildling/syntax.html) · [Source](https://github.com/dotmonk/wildling/tree/main/javascript)

**Registry:** [npm](https://www.npmjs.com/package/wildling)

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

**Registry:**

```bash
npm install wildling
```

**Git (monorepo subdirectory):**

```bash
npm install "git+https://github.com/dotmonk/wildling.git#v2.0.5:javascript"
```

`prepare` builds `dist/` when missing (Node 18+, network for TypeScript on first install).

In `package.json`:

```json
"wildling": "github:dotmonk/wildling#v2.0.5:javascript"
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
  patterns: ["abrakadabra", "Year 19##"],
  dictionaries: {
    colors: ["red", "blue"],
  },
});

wildling.count(); // 101
wildling.get(0); // "abrakadabra"

let value;
while ((value = wildling.next()) !== false) {
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
./bin/wildling "Year 19##"
./bin/wildling --dictionary planets:../dictionaries/planets.txt "%{'planets'}"
./bin/wildling --select 0 --range 8-9 "##"
./bin/wildling --template ./config.json
```

### Template JSON

```json
{
  "patterns": ["Year 19##", "%{'colors'}"],
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
