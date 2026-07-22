# wildling (Assembly)

x86-64 Linux NASM port of wildling. Every piece of wildling logic — string
utilities, growable vectors/dictionaries, token expansion, hand-rolled
(non-regex) pattern splitting, JSON template parsing, and the CLI itself — is
written directly in NASM assembly. There is **no C or C++ source** for
wildling logic; `gcc` is used only as the linker/CRT so the assembly can call
into `glibc` (`malloc`, `free`, `strlen`, `strcmp`, `printf`, `fprintf`,
`fopen`, `fread`, `fclose`, `exit`, `atoi`, `strtod`, …).

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
./bin/wildling "foo#"
./bin/wildling --help

From a release tag:

```bash
git clone --branch v2.0.0 --depth 1 https://github.com/dotmonk/wildling.git
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
