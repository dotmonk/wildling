function New-WildlingCliArgs {
    return [pscustomobject]@{
        Selects      = New-Object System.Collections.Generic.List[int]
        Ranges       = New-Object System.Collections.Generic.List[object]
        Check        = $false
        Dictionaries = [ordered]@{}
        Patterns     = New-Object System.Collections.Generic.List[string]
        Help         = $false
        Version      = $false
    }
}

function ConvertFrom-WildlingRange {
    param([string] $Value)

    $dash = $Value.IndexOf('-')
    if ($dash -le 0 -or $dash -eq ($Value.Length - 1)) {
        return $null
    }

    $startText = $Value.Substring(0, $dash)
    $endText = $Value.Substring($dash + 1)
    if ($startText -notmatch '^\d+$' -or $endText -notmatch '^\d+$') {
        return $null
    }

    $start = [int]$startText
    $end = [int]$endText
    if ($start -gt $end) {
        return $null
    }

    return [pscustomobject]@{ Start = $start; End = $end }
}

function Get-WildlingDictionaryFile {
    param([string] $Path)

    return @(
        Get-Content -LiteralPath $Path -Encoding UTF8 |
            ForEach-Object { $_.Trim() } |
            Where-Object { $_ -ne '' }
    )
}

function Add-WildlingDictionary {
    param(
        $Result,
        [string] $Name,
        $Value
    )

    if ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string]) {
        $Result.Dictionaries[$Name] = @($Value | ForEach-Object { "$_" })
        return
    }

    $path = [string]$Value
    if ($path -and (Test-Path -LiteralPath $path)) {
        try {
            $Result.Dictionaries[$Name] = Get-WildlingDictionaryFile -Path $path
        }
        catch {
            # ignore unreadable dictionary files
        }
    }
}

function Import-WildlingTemplate {
    param(
        $Result,
        [string] $Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        [Console]::Error.WriteLine("Template file not found: $Path")
        exit 1
    }

    try {
        $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
        $template = $raw | ConvertFrom-Json
    }
    catch {
        [Console]::Error.WriteLine("Invalid JSON template: $Path")
        exit 1
    }

    if ($template -isnot [pscustomobject]) {
        [Console]::Error.WriteLine("Invalid JSON template: $Path")
        exit 1
    }

    if ($template.check -eq $true) {
        $Result.Check = $true
    }

    if ($null -ne $template.select) {
        foreach ($val in @($template.select)) {
            $number = 0
            if ([int]::TryParse([string]$val, [ref]$number) -and $number -ge 0) {
                $Result.Selects.Add($number)
            }
        }
    }

    if ($null -ne $template.range) {
        foreach ($rangeStr in @($template.range)) {
            $parsed = ConvertFrom-WildlingRange -Value ([string]$rangeStr)
            if ($null -ne $parsed) {
                $Result.Ranges.Add($parsed)
            }
        }
    }

    if ($null -ne $template.dictionaries) {
        foreach ($prop in $template.dictionaries.PSObject.Properties) {
            Add-WildlingDictionary -Result $Result -Name $prop.Name -Value $prop.Value
        }
    }

    if ($null -ne $template.patterns) {
        foreach ($pattern in @($template.patterns)) {
            $Result.Patterns.Add([string]$pattern)
        }
    }
}

function ConvertFrom-WildlingCliArgs {
    param([string[]] $Argv)

    $result = New-WildlingCliArgs
    $i = 0
    while ($i -lt $Argv.Count) {
        $arg = $Argv[$i]

        switch ($arg) {
            { $_ -in @('--help', '-h') } {
                $result.Help = $true
                $i++
                continue
            }
            { $_ -in @('--version', '-v') } {
                $result.Version = $true
                $i++
                continue
            }
            '--check' {
                $result.Check = $true
                $i++
                continue
            }
            '--select' {
                $i++
                if ($i -ge $Argv.Count) { break }
                $number = 0
                if ([int]::TryParse($Argv[$i], [ref]$number) -and $number -ge 0) {
                    $result.Selects.Add($number)
                }
                $i++
                continue
            }
            '--range' {
                $i++
                if ($i -ge $Argv.Count) { break }
                $parsed = ConvertFrom-WildlingRange -Value $Argv[$i]
                if ($null -ne $parsed) {
                    $Result.Ranges.Add($parsed)
                }
                $i++
                continue
            }
            '--dictionary' {
                $i++
                if ($i -ge $Argv.Count) { break }
                $spec = $Argv[$i]
                $colon = $spec.IndexOf(':')
                if ($colon -gt 0 -and $colon -lt ($spec.Length - 1)) {
                    $name = $spec.Substring(0, $colon)
                    $path = $spec.Substring($colon + 1)
                    Add-WildlingDictionary -Result $result -Name $name -Value $path
                }
                $i++
                continue
            }
            '--template' {
                $i++
                if ($i -ge $Argv.Count) {
                    [Console]::Error.WriteLine('Missing path for --template')
                    exit 1
                }
                Import-WildlingTemplate -Result $result -Path $Argv[$i]
                $i++
                continue
            }
            default {
                $result.Patterns.Add($arg)
                $i++
            }
        }
    }

    return $result
}

function Get-WildlingHelpText {
    $libDir = $PSScriptRoot
    $root = Split-Path -Parent $libDir
    $candidates = @(
        (Join-Path $root 'help.txt'),
        (Join-Path $root '..' 'docs' 'help.txt')
    )

    foreach ($path in $candidates) {
        if (Test-Path -LiteralPath $path) {
            return Get-Content -LiteralPath $path -Raw -Encoding UTF8
        }
    }

    return "wildling - pattern based string generator`n`nHelp text unavailable.`n"
}

function Format-WildlingList {
    param([object[]] $Values)

    if ($null -eq $Values -or $Values.Count -eq 0) {
        return ''
    }
    return ' ' + (($Values | ForEach-Object { "$_" }) -join ' ')
}

function Format-WildlingCheckOutput {
    param(
        $CliArgs,
        [int] $Total,
        [WildlingGenerator[]] $Generators
    )

    $rangeValues = @($CliArgs.Ranges | ForEach-Object { "$($_.Start)-$($_.End)" })
    $lines = @(
        "patterns:$(Format-WildlingList @($CliArgs.Patterns))",
        "dictionaries:$(Format-WildlingList @($CliArgs.Dictionaries.Keys))",
        "select:$(Format-WildlingList @($CliArgs.Selects))",
        "range:$(Format-WildlingList $rangeValues)",
        "total: $Total"
    )

    foreach ($gen in $Generators) {
        $lines += "generator: $($gen.Source) $($gen.GetCount())"
    }

    return ($lines -join "`n")
}

function Write-WildlingValue {
    param([object] $Value)

    [Console]::Out.WriteLine([string]$Value)
}

function Invoke-WildlingCli {
    param([string[]] $Argv)

    $parsed = ConvertFrom-WildlingCliArgs -Argv $Argv

    if ($parsed.Help) {
        [Console]::Out.WriteLine((Get-WildlingHelpText).TrimEnd())
        exit 0
    }

    if ($parsed.Version) {
        [Console]::Out.WriteLine("wildling $Script:WildlingVersion")
        exit 0
    }

    if ($parsed.Patterns.Count -eq 0) {
        [Console]::Error.WriteLine('No pattern provided. Use --help for usage information.')
        exit 1
    }

    $wildcard = New-WildlingClient -Patterns @($parsed.Patterns) -Dictionaries $parsed.Dictionaries

    if ($parsed.Check) {
        [Console]::Out.WriteLine((Format-WildlingCheckOutput -CliArgs $parsed -Total $wildcard.GetCount() -Generators $wildcard.GetGenerators()))
        exit 0
    }

    if ($parsed.Selects.Count -gt 0 -or $parsed.Ranges.Count -gt 0) {
        $oor = $false
        foreach ($index in $parsed.Selects) {
            $value = $wildcard.Get($index)
            if ($value -is [bool] -and $value -eq $false) {
                [Console]::Error.WriteLine("out of range: $index")
                $oor = $true
            }
            else {
                Write-WildlingValue $value
            }
        }
        foreach ($range in $parsed.Ranges) {
            for ($index = $range.Start; $index -le $range.End; $index++) {
                $value = $wildcard.Get($index)
                if ($value -is [bool] -and $value -eq $false) {
                    [Console]::Error.WriteLine("out of range: $index")
                    $oor = $true
                }
                else {
                    Write-WildlingValue $value
                }
            }
        }
        if ($oor) { exit 1 } else { exit 0 }
    }

    $value = $wildcard.Next()
    while ($value -isnot [bool] -or $value -ne $false) {
        Write-WildlingValue $value
        $value = $wildcard.Next()
    }
}
