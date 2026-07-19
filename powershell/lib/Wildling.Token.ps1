class WildlingToken {
    [string] $Src
    [int] $StartLength
    [int] $EndLength
    [string[]] $Variants
    [int] $Count

    WildlingToken([hashtable] $options) {
        $this.Src = [string]$options['src']
        if (-not $this.Src) { $this.Src = '' }

        $this.StartLength = [WildlingToken]::DefaultInteger($options['startLength'], 1)
        $this.EndLength = [WildlingToken]::DefaultInteger($options['endLength'], 1)
        $this.Variants = @($options['variants'])
        if (-not $this.Variants) { $this.Variants = @() }

        $total = 0
        for ($length = $this.StartLength; $length -le $this.EndLength; $length++) {
            $total += [WildlingToken]::Pow($this.Variants.Count, $length)
        }
        $this.Count = $total
    }

    static [int] DefaultInteger($option, [int] $fallback) {
        if ($null -ne $option -and $option -is [int] -and $option -ge 0) {
            return $option
        }
        return $fallback
    }

    static [int] Pow([int] $baseValue, [int] $exp) {
        $result = 1
        for ($i = 0; $i -lt $exp; $i++) {
            $result *= $baseValue
        }
        return $result
    }

    [int] GetCount() {
        return $this.Count
    }

    [string] GetSrc() {
        return $this.Src
    }

    [string] Get([int] $index) {
        if ($index -gt ($this.Count - 1) -or $index -lt 0) {
            return ''
        }

        if ($index -eq 0 -and $this.StartLength -eq 0) {
            return ''
        }

        $indexWithOffset = $index
        $stringLength = $this.StartLength
        for ($length = $this.StartLength; $length -le $this.EndLength; $length++) {
            $stringLength = $length
            $offsetCount = [WildlingToken]::Pow($this.Variants.Count, $length)
            if ($indexWithOffset -lt $offsetCount) {
                break
            }
            $indexWithOffset -= $offsetCount
        }

        $stringArray = New-Object System.Collections.Generic.List[string]
        for ($i = 0; $i -lt $stringLength; $i++) {
            $variantIndex = $indexWithOffset % $this.Variants.Count
            $indexWithOffset = [math]::Floor($indexWithOffset / $this.Variants.Count)
            $stringArray.Add($this.Variants[$variantIndex])
        }
        return [string]::Join('', $stringArray)
    }
}

function New-WildlingToken {
    param([hashtable] $Options)
    return [WildlingToken]::new($Options)
}
