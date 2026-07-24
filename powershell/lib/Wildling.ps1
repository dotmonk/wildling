$Script:WildlingVersion = '2.0.5'

class WildlingClient {
    [WildlingGenerator[]] $Generators
    [int] $PatternCount
    [int] $InternalIndex

    WildlingClient([string[]] $patterns, [hashtable] $dictionaries) {
        if ($null -eq $dictionaries) {
            $dictionaries = [ordered]@{}
        }

        $generatorList = New-Object System.Collections.Generic.List[WildlingGenerator]
        $total = 0
        foreach ($pattern in $patterns) {
            $generator = New-WildlingGenerator -InputPattern $pattern -Dictionaries $dictionaries
            $generatorList.Add($generator)
            $total += $generator.GetCount()
        }

        $this.Generators = $generatorList.ToArray()
        $this.PatternCount = $total
        $this.InternalIndex = 0
    }

    [int] GetIndex() {
        return $this.InternalIndex
    }

    [int] GetCount() {
        return $this.PatternCount
    }

    [void] Reset() {
        $this.InternalIndex = 0
    }

    [object] Next() {
        if ($this.InternalIndex -eq $this.PatternCount) {
            return $false
        }
        $this.InternalIndex++
        return $this.Get($this.InternalIndex - 1)
    }

    [WildlingGenerator[]] GetGenerators() {
        return $this.Generators
    }

    [object] Get([int] $index) {
        if ($index -gt ($this.PatternCount - 1) -or $index -lt 0) {
            return $false
        }

        $segmentIndex = 0
        foreach ($generator in $this.Generators) {
            $patternIndex = $index - $segmentIndex
            if ($patternIndex -lt $generator.GetCount()) {
                return $generator.Get($patternIndex)
            }
            $segmentIndex += $generator.GetCount()
        }
        return $false
    }
}

function New-WildlingClient {
    param(
        [string[]] $Patterns,
        [hashtable] $Dictionaries
    )
    return [WildlingClient]::new($Patterns, $Dictionaries)
}
