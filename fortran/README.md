# wildling

Fortran library and CLI for pattern-based string generation. **Zero third-party libraries** — ISO Fortran / gfortran only, with a hand-rolled JSON parser for `--template`. Pattern splitting is hand-rolled (no regex).

<!-- wildling:preamble -->
**Docs:** [Website](https://dotmonk.github.io/wildling/) · [Sandbox](https://dotmonk.github.io/wildling/sandbox.html) · [Syntax](https://dotmonk.github.io/wildling/syntax.html) · [Source](https://github.com/dotmonk/wildling/tree/main/fortran)

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
cd fortran
./build.sh
./bin/wildling "Year 19##"
```

From a release tag:

```bash
git clone --branch v2.0.0 --depth 1 https://github.com/dotmonk/wildling.git
cd wildling
./build.sh fortran
```

Produces `dist/wildling`. Use the modules under `src/` (except `cli.f90`) as a library.

```fortran
use wl_util
use wl_wildling

type(str_list) :: patterns
type(dictionaries) :: dicts
type(wildling_t) :: w
character(len=:), allocatable :: value

call str_list_init(patterns)
call str_list_push(patterns, 'Year 19##')
call dictionaries_init(dicts)
call wildling_init(w, patterns, dicts)
do
  if (.not. wildling_next(w, value)) exit
  print '(A)', value
end do
call wildling_free(w)
```

## CLI

```bash
./bin/wildling "Year 19##"
./bin/wildling --dictionary planets:../dictionaries/planets.txt "%{'planets'}"
./bin/wildling --template ./config.json
```

Help text and `--check` output follow [`docs/cli.md`](../docs/cli.md) / [`docs/help.txt`](../docs/help.txt). Out-of-range `--select` / `--range` write `out of range: <index>` on stderr and exit `1`.

## Build

```bash
./build.sh   # Docker (gcc:14-bookworm + gfortran): → dist/wildling + help.txt
```

Project tests live in `../tests/` and are run with `../test.sh`.

## Layout

```
fortran/
  src/
    util.f90           string lists + dictionaries
    token.f90          token expansion
    parse_pattern.f90  hand-rolled pattern split + tokenizers
    generator.f90      single-pattern generator
    wildling.f90       multi-pattern API
    json.f90           template JSON parser
    cli.f90            CLI entry point
  bin/wildling         launcher script
  build.sh             Docker build (gfortran)
  dist/                build output (gitignored)
```
