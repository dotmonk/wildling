# wildling (R)

R library and CLI for pattern-based string generation. **Zero third-party dependencies** (base R only — hand-rolled JSON parser). Requires R 3.5+ with base packages only.

## Install

From this repository:

```bash
cd r
./build.sh
./bin/wildling "foo#"
```

**Git:**

```r
remotes::install_github("dotmonk/wildling", subdir = "r", ref = "v2.0.0")
```

```r
root <- normalizePath("r")
source(file.path(root, "lib", "wildling", "token.R"))
source(file.path(root, "lib", "wildling", "parse_pattern.R"))
source(file.path(root, "lib", "wildling", "generator.R"))
source(file.path(root, "lib", "wildling", "wildling.R"))

w <- create_wildling(c("foo#"))
value <- w$`next`()
while (!isFALSE(value)) {
  cat(value, "\n")
  value <- w$`next`()
}
```

## CLI

```bash
./bin/wildling "foo#"
./bin/wildling --dictionary planets:../dictionaries/planets.txt "%{'planets'}"
./bin/wildling --template ./config.json
```

Help text and `--check` output follow [`docs/cli.md`](../docs/cli.md) / [`docs/help.txt`](../docs/help.txt).

## Build

```bash
./build.sh   # Docker (gcc:14-bookworm + r-base-core): copy help.txt + R parse check
```

Project tests live in `../tests/` and are run with `../test.sh`.
