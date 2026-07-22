# wildling (Fortran)

Fortran library and CLI for pattern-based string generation. **Zero third-party libraries** — ISO Fortran / gfortran only, with a hand-rolled JSON parser for `--template`. Pattern splitting is hand-rolled (no regex).

## Install

From this repository:

```bash
cd fortran
./build.sh
./bin/wildling "foo#"
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
call str_list_push(patterns, 'foo#')
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
./bin/wildling "foo#"
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
