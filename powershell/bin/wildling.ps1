#Requires -Version 5.1

$ErrorActionPreference = 'Stop'

$WildlingArgv = @($args)

$LibDir = Join-Path (Split-Path -Parent $PSScriptRoot) 'lib'
. (Join-Path $LibDir 'Wildling.Token.ps1')
. (Join-Path $LibDir 'Wildling.ParsePattern.ps1')
. (Join-Path $LibDir 'Wildling.Generator.ps1')
. (Join-Path $LibDir 'Wildling.ps1')
. (Join-Path $LibDir 'Wildling.Cli.ps1')

Invoke-WildlingCli -Argv $WildlingArgv
