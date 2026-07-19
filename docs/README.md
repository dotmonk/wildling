# Wildling documentation

Pattern-based string generator — one shared grammar, many native libraries and CLIs.

## Website

- Site: [https://dotmonk.github.io/wildling/](https://dotmonk.github.io/wildling/)
- [Pattern syntax](https://dotmonk.github.io/wildling/syntax.html)
- [Browser sandbox](https://dotmonk.github.io/wildling/sandbox.html) (JavaScript engine; patterns are the same across ports)
- [Language READMEs](https://dotmonk.github.io/wildling/#languages)

Site sources live in [`site/`](../site/). Build locally with [`../scripts/build-site.sh`](../scripts/build-site.sh).

## Pattern cliff notes

| Token | Meaning |
|-------|---------|
| `#` | digits `0-9` |
| `@` | lowercase `a-z` |
| `*` | lowercase + digits |
| `&` | letters `a-zA-Z` |
| `!` | uppercase `A-Z` |
| `?` | uppercase + digits |
| `-` | letters + digits |
| `${'a,b',N-M}` | combinations from a word list |
| `%{'name'}` | words from a named dictionary |
| `\#` etc. | escape a wildcard character |

Optional length: `#{2}`, `@{1-3}`, `%{'colors',0-1}`.

Full reference: [syntax page](https://dotmonk.github.io/wildling/syntax.html) and [`help.txt`](help.txt).

## CLI contracts

Shared `--help` text and `--check` formatting: [`cli.md`](cli.md) · [`help.txt`](help.txt).

Out-of-range `--select` / `--range`: nothing on stdout for that index, one
`out of range: <index>` line on stderr, exit `1` if any were out of range.
See [`cli.md`](cli.md).

## Library usage (JavaScript)

From this repository:

```bash
cd javascript && npm ci --include=dev && npm run build
```

```js
const createWildling = require("./dist/index.js").default;

const wildling = createWildling({
  patterns: ["abrakadabra", "foo#"],
  dictionaries: {},
});

let value;
while ((value = wildling.next())) {
  console.log(value);
}
```

Other languages: see each `<language>/README.md` in the repo root.

## Why?

Useful for wordlists, domain brainstorming, and test data. Example idea: combine
dictionaries and length ranges to enumerate candidate domain names, then check
availability outside wildling.

## License

MIT — see [`../LICENSE`](../LICENSE).
