$Script:WildlingTokenParsingRegex = [regex]'(\\[%@$*#&?!-]|[%@$*#&?!-]\{.*?\}|[%@$*#&?!-])'
$Script:WildlingLengthWithVariantsRegex = [regex]'\{((\d+)-(\d+)|(\d+))\}'
$Script:WildlingLengthWithStringRegex = [regex]'\{''(.*)''(?:,(\d+)-(\d+))?(?:,(\d+))?\}'

function Get-WildlingLengthWithVariants {
    param(
        [string] $Part,
        [string[]] $Variants
    )

    $startLength = 1
    $endLength = 1
    $match = $Script:WildlingLengthWithVariantsRegex.Match($Part)

    if ($match.Success) {
        if ($match.Groups[2].Success -and $match.Groups[2].Value.Length -gt 0) {
            $startLength = [int]$match.Groups[2].Value
            $endLength = [int]$match.Groups[3].Value
        }
        elseif ($match.Groups[1].Success) {
            $startLength = [int]$match.Groups[1].Value
            $endLength = $startLength
        }
    }

    return @{
        variants    = $Variants
        startLength = $startLength
        endLength   = $endLength
        src         = $Part
    }
}

function Get-WildlingLengthWithString {
    param([string] $Part)

    $match = $Script:WildlingLengthWithStringRegex.Match($Part)
    if (-not $match.Success) {
        return $null
    }

    if ($match.Groups[2].Success -and $match.Groups[3].Success) {
        return @{
            string      = $match.Groups[1].Value
            startLength = [int]$match.Groups[2].Value
            endLength   = [int]$match.Groups[3].Value
            src         = $Part
        }
    }

    if ($match.Groups[4].Success) {
        $length = [int]$match.Groups[4].Value
        return @{
            string      = $match.Groups[1].Value
            startLength = $length
            endLength   = $length
            src         = $Part
        }
    }

    return @{
        string      = $match.Groups[1].Value
        startLength = 1
        endLength   = 1
        src         = $Part
    }
}

function New-WildlingSimpleTokenizer {
    param([string] $VariantsString)

    $variants = @($VariantsString.ToCharArray() | ForEach-Object { "$_" })
    return {
        param([string] $Part)
        New-WildlingToken (Get-WildlingLengthWithVariants -Part $Part -Variants $variants)
    }.GetNewClosure()
}

function New-WildlingDictionaryToken {
    param(
        [string] $Part,
        [hashtable] $Dictionaries
    )

    $options = Get-WildlingLengthWithString -Part $Part
    if ($null -eq $options -or (
            $options.string -and
            -not $Dictionaries.Contains($options.string)
        )) {
        $options = @{
            variants    = @($Part)
            startLength = 1
            endLength   = 1
            src         = $Part
        }
    }
    else {
        $key = [string]$options.string
        if ($Dictionaries.Contains($key)) {
            $options.variants = @($Dictionaries[$key])
        }
        else {
            $options.variants = @()
        }
    }

    return New-WildlingToken $options
}

function New-WildlingWordsToken {
    param([string] $Part)

    $options = Get-WildlingLengthWithString -Part $Part
    if ($null -eq $options) {
        $options = @{
            variants    = @($Part)
            startLength = 1
            endLength   = 1
            src         = $Part
        }
    }
    else {
        $variants = New-Object System.Collections.Generic.List[string]
        $workString = [string]$options.string
        $index = 0
        while ($index -lt $workString.Length) {
            if (($index + 1) -lt $workString.Length -and
                $workString.Substring($index, 2) -eq '\,') {
                $index += 2
            }
            elseif ($workString[$index] -eq ',') {
                $variants.Add($workString.Substring(0, $index))
                $workString = $workString.Substring($index + 1)
                $index = 0
            }
            else {
                $index++
            }
        }
        $variants.Add($workString)
        $options.variants = @($variants | ForEach-Object { $_.Replace('\,', ',') })
    }

    return New-WildlingToken $options
}

function ConvertTo-WildlingToken {
    param(
        [string] $Part,
        [hashtable] $Dictionaries
    )

    $tokenizers = @{
        '#' = (New-WildlingSimpleTokenizer '0123456789')
        '@' = (New-WildlingSimpleTokenizer 'abcdefghijklmnopqrstuvwxyz')
        '*' = (New-WildlingSimpleTokenizer 'abcdefghijklmnopqrstuvwxyz0123456789')
        '-' = (New-WildlingSimpleTokenizer 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789')
        '!' = (New-WildlingSimpleTokenizer 'ABCDEFGHIJKLMNOPQRSTUVWXYZ')
        '?' = (New-WildlingSimpleTokenizer 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789')
        '&' = (New-WildlingSimpleTokenizer 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ')
        '%' = { param([string] $p) New-WildlingDictionaryToken -Part $p -Dictionaries $Dictionaries }
        '$' = { param([string] $p) New-WildlingWordsToken -Part $p }
    }

    $firstChar = if ($Part.Length -gt 0) { [string]$Part[0] } else { '' }
    $secondChar = if ($Part.Length -gt 1) { [string]$Part[1] } else { '' }

    $tokenizer = $null
    if ($firstChar -and $tokenizers.ContainsKey($firstChar)) {
        $tokenizer = $tokenizers[$firstChar]
    }

    $isEscapedToken = ($Part.Length -gt 1) -and ($firstChar -eq '\') -and $tokenizers.ContainsKey($secondChar)

    if ($null -ne $tokenizer) {
        return & $tokenizer $Part
    }

    if ($isEscapedToken) {
        return New-WildlingToken @{
            variants = @($Part.Substring(1))
            src      = $Part
        }
    }

    return New-WildlingToken @{
        variants = @($Part)
        src      = $Part
    }
}

function ConvertTo-WildlingTokens {
    param(
        [string] $InputPattern,
        [hashtable] $Dictionaries
    )

    if ($null -eq $Dictionaries) {
        $Dictionaries = [ordered]@{}
    }

    $parts = $Script:WildlingTokenParsingRegex.Split($InputPattern) |
        Where-Object { $_ -ne '' }

    return @($parts | ForEach-Object { ConvertTo-WildlingToken -Part $_ -Dictionaries $Dictionaries })
}
