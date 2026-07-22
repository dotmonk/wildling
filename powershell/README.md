# wildling (PowerShell)

Pattern-based string generator — library and CLI for PowerShell 5.1+ / PowerShell 7.

## Install

From this repository:

```bash
cd powershell
./build.sh
```

From a release tag:

```bash
git clone --branch v2.0.0 --depth 1 https://github.com/dotmonk/wildling.git
cd wildling
./build.sh powershell
```

**Registry:** PowerShell Gallery `Wildling` (when published)

## Build

Requires Docker (host does not need `pwsh` installed):

```bash
./build.sh
```

Copies shared help text from `docs/help.txt` and syntax-checks all `.ps1` files inside `mcr.microsoft.com/powershell`.

## CLI

```bash
./bin/wildling "foo#"
./bin/wildling --help
./bin/wildling --check "##"
```

If `pwsh` or `powershell` is on `PATH`, the launcher runs locally. Otherwise it falls back to Docker (`mcr.microsoft.com/powershell`).

## Library

Dot-source the library files (or import as a module):

```powershell
$LibDir = Join-Path $PSScriptRoot 'lib'
. (Join-Path $LibDir 'Wildling.Token.ps1')
. (Join-Path $LibDir 'Wildling.ParsePattern.ps1')
. (Join-Path $LibDir 'Wildling.Generator.ps1')
. (Join-Path $LibDir 'Wildling.ps1')

$wildling = New-WildlingClient -Patterns @('foo#') -Dictionaries ([ordered]@{})
$value = $wildling.Next()
while ($value -isnot [bool] -or $value -ne $false) {
    Write-Output $value
    $value = $wildling.Next()
}
```

Shared CLI contracts: [docs/cli.md](../docs/cli.md).
