class WildlingGenerator {
    [string] $Source
    [WildlingToken[]] $Tokens
    [int] $CountValue

    WildlingGenerator([string] $inputPattern, [hashtable] $dictionaries) {
        $this.Source = $inputPattern
        $this.Tokens = [WildlingToken[]](ConvertTo-WildlingTokens -InputPattern $inputPattern -Dictionaries $dictionaries)

        $total = 1
        foreach ($token in $this.Tokens) {
            $total *= $token.GetCount()
        }
        $this.CountValue = $total
    }

    [int] GetCount() {
        return $this.CountValue
    }

    [WildlingToken[]] GetTokens() {
        return $this.Tokens
    }

    [string] Get([int] $index) {
        if ($index -gt ($this.CountValue - 1) -or $index -lt 0) {
            return ''
        }

        $parts = New-Object System.Collections.Generic.List[string]
        $indexWithOffset = $index
        foreach ($token in $this.Tokens) {
            $tokenCount = $token.GetCount()
            $parts.Add($token.Get($indexWithOffset % $tokenCount))
            $indexWithOffset = [math]::Floor($indexWithOffset / $tokenCount)
        }
        return [string]::Join('', $parts)
    }
}

function New-WildlingGenerator {
    param(
        [string] $InputPattern,
        [hashtable] $Dictionaries
    )
    return [WildlingGenerator]::new($InputPattern, $Dictionaries)
}
