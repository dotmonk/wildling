# wildling — architecture notes

Pattern-based string generator: shared grammar + CLI contracts, one library and
CLI per language. Product docs live in [`docs/`](docs/) and on the
[website](https://dotmonk.github.io/wildling/).

## Principles

- **Zero third-party runtime deps** outside each language’s standard library
- **Docker builds** via `*/build.sh` (host needs Docker + a shell)
- **Shared fixtures** in `tests/`; `./test.sh` compares CLI stdout to expected
- **CLI contracts** in [`docs/cli.md`](docs/cli.md) and [`docs/help.txt`](docs/help.txt)

## Language stack summary

| Id | Stack |
|----|--------|
| javascript | TypeScript → Node (zero runtime npm deps) |
| python | Python 3.9+ stdlib |
| java | JDK 11+ stdlib, hand-rolled JSON |
| csharp / visualbasic / fsharp | .NET 8 BCL (`System.Text.Json`) |
| cpp | C++17 stdlib |
| php | PHP 8.1+ stdlib |
| c | C11 + POSIX `regex.h`, hand-rolled JSON |
| go | Go 1.22+ stdlib |
| rust | Rust 2021, std only |
| kotlin / scala / groovy | JVM 11+, hand-rolled JSON |
| ruby | Ruby 3+ stdlib |
| swift | Swift 6 / Foundation |
| dart | Dart 3 stdlib |
| posix-shell | POSIX sh + awk |
| powershell | PowerShell / BCL |
| lua | Lua 5.4 stdlib |
| assembly | x86-64 NASM + glibc link |
| r | R base only |
| perl | Perl core only |
| elixir | Elixir / OTP stdlib |
| pascal | Free Pascal RTL |
| zig | Zig stdlib |
| fortran | ISO Fortran / gfortran |
| ada | Ada 2012 / GNAT |
| haskell | GHC boot libraries |

Canonical id list: [`languages.txt`](languages.txt).

## Building and CI

- Root: `./build.sh [langs…]`, `./test.sh [langs…]`
- Site: `./scripts/build-site.sh` → `_site/`
- GitHub Actions: `.github/workflows/test.yml` (fixture matrix),
  `.github/workflows/pages.yml` (Pages deploy)

## CLI shape

```
wildling [options] [pattern ...]
```

Options (see `docs/help.txt`): `--select`, `--range`, `--check`, `--dictionary`,
`--template`, `--help`, `--version`. Out-of-range select/range → empty stdout for
that index, stderr `out of range: N`, exit `1` if any index was invalid (see
`docs/cli.md`). Do not print the word `false` on stdout.
