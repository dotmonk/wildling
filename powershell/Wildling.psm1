# Wildling PowerShell module entrypoint
$lib = Join-Path $PSScriptRoot 'lib'
. (Join-Path $lib 'Wildling.Token.ps1')
. (Join-Path $lib 'Wildling.ParsePattern.ps1')
. (Join-Path $lib 'Wildling.Generator.ps1')
. (Join-Path $lib 'Wildling.ps1')
. (Join-Path $lib 'Wildling.Cli.ps1')
