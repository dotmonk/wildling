# wildling (Ada)

GNAT Ada library and CLI for pattern-based string generation. **Zero third-party crates** — Ada standard library only (`Ada.*`) with a hand-rolled JSON parser for `--template`. Pattern splitting is hand-rolled (no regex package).

## Install

From this repository:

```bash
cd ada
./build.sh
./bin/wildling "foo#"
```

Produces `dist/wildling`. Use the packages under `src/` (except `cli.adb`) as a library.

```ada
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Text_IO;
with Parse_Pattern; use Parse_Pattern;
with Token; use Token;
with Wildling; use Wildling;

procedure Example is
   Patterns : String_List;
   Dicts    : Dictionaries;
   W        : Wildling_Type;
   Value    : Unbounded_String;
begin
   Patterns.Append (To_Unbounded_String ("foo#"));
   W := Create (Patterns, Dicts);
   while Next (W, Value) loop
      Ada.Text_IO.Put_Line (To_String (Value));
   end loop;
end Example;
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
./build.sh   # Docker (gcc:14-bookworm + gnat/gprbuild): → dist/wildling + help.txt
```

Project tests live in `../tests/` and are run with `../test.sh`.

## Layout

```
ada/
  src/
    token.ads/.adb         token expansion
    parse_pattern.ads/.adb hand-rolled pattern split + tokenizers
    generator.ads/.adb     single-pattern generator
    wildling.ads/.adb      multi-pattern API
    json.ads/.adb          template JSON parser
    cli.adb                CLI entry point
  wildling.gpr             GPRbuild project
  bin/wildling             launcher script
  build.sh                 Docker build (gnat/gprbuild via apt)
  dist/                    build output (gitignored)
  obj/                     compiler units (gitignored)
```
