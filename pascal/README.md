# wildling (Free Pascal)

Free Pascal library and CLI for pattern-based string generation. **Zero third-party units** — FPC RTL only (`System`, `SysUtils`) with a hand-rolled JSON parser for `--template`. Pattern splitting is hand-rolled (no RegExpr).

## Install

From this repository:

```bash
cd pascal
./build.sh
./bin/wildling "foo#"
```

Produces `dist/wildling`. Use the units under `src/` (except `cli.pas`) as a library.

```pascal
uses WildlingLib, ParsePattern;

var
  W: TWildling;
  Value: string;
begin
  W := CreateWildling(['foo#']);
  try
    while W.Next(Value) do
      WriteLn(Value);
  finally
    W.Free;
  end;
end.
```

## CLI

```bash
./bin/wildling "foo#"
./bin/wildling --dictionary planets:../dictionaries/planets.txt "%{'planets'}"
./bin/wildling --template ./config.json
```

Help text and `--check` output follow [`docs/cli.md`](../docs/cli.md) / [`docs/help.txt`](../docs/help.txt). Out-of-range `--select` / `--range` indices print lowercase `false`.

## Build

```bash
./build.sh   # Docker (gcc:14-bookworm + fpc): → dist/wildling + help.txt
```

Project tests live in `../tests/` and are run with `../test.sh`.

## Layout

```
pascal/
  src/
    token.pas         token expansion
    parsepattern.pas  hand-rolled pattern split + tokenizers
    generator.pas     single-pattern generator
    wildlinglib.pas   multi-pattern API
    json.pas          template JSON parser
    cli.pas           CLI entry point
  bin/wildling        launcher script
  build.sh            Docker build (fpc via apt)
  dist/               build output (gitignored)
  obj/                compiler units (gitignored)
```
