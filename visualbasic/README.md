# wildling (Visual Basic / VB.NET)

Visual Basic library and CLI for pattern-based string generation. **Zero NuGet dependencies** (.NET BCL only). Targets .NET 8.

## Install

From this repository:

```bash
cd visualbasic
./build.sh
./bin/wildling "foo#"
```

Produces `dist/wildling.dll` (and dependencies). Requires the .NET 8 runtime, or Docker (the launcher falls back to the runtime image if `dotnet` is not on `PATH`).

As a library, reference the project or published assembly:

```vb
Imports WildlingLib

Dim wildling = Wildling.Create({"foo#"})
Dim value As Object = wildling.Next()
While Not (TypeOf value Is Boolean AndAlso Not CBool(value))
    Console.WriteLine(value)
    value = wildling.Next()
End While
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
./build.sh   # Docker (dotnet SDK 8): publish to dist/, copies help.txt
```

Project tests live in `../tests/` and are run with `../test.sh`.
