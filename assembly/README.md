# wildling

x86-64 Linux NASM port of wildling. Every piece of wildling logic — string
utilities, growable vectors/dictionaries, token expansion, hand-rolled
(non-regex) pattern splitting, JSON template parsing, and the CLI itself — is
written directly in NASM assembly. There is **no C or C++ source** for
wildling logic; `gcc` is used only as the linker/CRT so the assembly can call
into `glibc` (`malloc`, `free`, `strlen`, `strcmp`, `printf`, `fprintf`,
`fopen`, `fread`, `fclose`, `exit`, `atoi`, `strtod`, …).

<!-- wildling:preamble -->
**Docs:** [Website](https://dotmonk.github.io/wildling/) · [Sandbox](https://dotmonk.github.io/wildling/sandbox.html) · [Syntax](https://dotmonk.github.io/wildling/syntax.html) · [Source](https://github.com/dotmonk/wildling/tree/main/assembly)

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

## Stack

- NASM (`elf64`, System V AMD64 ABI)
- gcc 14 (Docker `gcc:14-bookworm`) for linking against glibc's CRT only
- glibc (`malloc`, `printf`, `strtod`, …) — no POSIX regex; pattern splitting
  is hand-rolled

## Build

```bash
./build.sh
```

Produces `dist/wildling` and copies shared `dist/help.txt`. The build runs
entirely inside Docker (`gcc:14-bookworm`): `nasm` is installed via `apt`,
every `.asm` file under `src/` is assembled with `nasm -f elf64`, and the
resulting object files are linked with `gcc -o dist/wildling src/*.o`.

## CLI

```bash
./bin/wildling "Year 19##"
./bin/wildling --help

From a release tag:

```bash
git clone --branch v2.0.3 --depth 1 https://github.com/dotmonk/wildling.git
cd wildling
./build.sh assembly
```
```

Shared CLI contracts: [../docs/cli.md](../docs/cli.md).

## Layout

```
assembly/
  src/
    macros.inc         shared struct offsets / stack helpers
    util.asm            strings, growable vectors, dictionaries, file I/O
    token.asm            token expansion
    parse_pattern.asm   hand-rolled (no regex) pattern split + tokenizers
    generator.asm       single-pattern generator
    wildling.asm        multi-pattern API
    json.asm            template JSON parser
    cli.asm             CLI entry point (main), argument parsing, --check
  bin/wildling          launcher script
  build.sh              Docker build (nasm + gcc, glibc link only)
  dist/                 build output (gitignored)
```
