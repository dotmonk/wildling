# wildling

Pattern-based string generator — library and CLI for PowerShell 5.1+ / PowerShell 7.

<!-- wildling:preamble -->
**Docs:** [Website](https://dotmonk.github.io/wildling/) · [Sandbox](https://dotmonk.github.io/wildling/sandbox.html) · [Syntax](https://dotmonk.github.io/wildling/syntax.html) · [Source](https://github.com/dotmonk/wildling/tree/main/powershell)

**Registry:** [PowerShell Gallery](https://www.powershellgallery.com/packages/Wildling)

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
cd powershell
./build.sh
```

From a release tag:

```bash
git clone --branch v2.0.4 --depth 1 https://github.com/dotmonk/wildling.git
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
./bin/wildling "Year 19##"
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

$wildling = New-WildlingClient -Patterns @('Year 19##') -Dictionaries ([ordered]@{})
$value = $wildling.Next()
while ($value -isnot [bool] -or $value -ne $false) {
    Write-Output $value
    $value = $wildling.Next()
}
```

Shared CLI contracts: [docs/cli.md](../docs/cli.md).
