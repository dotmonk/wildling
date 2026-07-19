namespace WildlingLib

open System.Collections.Generic

type Wildling
    (
        patterns: seq<string>,
        dictionaries: IReadOnlyDictionary<string, ResizeArray<string>> option
    ) =
    let dicts =
        defaultArg
            dictionaries
            (Dictionary<string, ResizeArray<string>>() :> IReadOnlyDictionary<_, _>)

    let generators =
        let gens = ResizeArray<Generator>()
        let mutable total = 0
        for pattern in patterns do
            let generator = Generator(pattern, Some dicts)
            gens.Add(generator)
            total <- total + generator.Count()
        gens, total

    let generatorsList, patternCount = generators
    let mutable internalIndex = 0

    static member Version = "1.0.0"

    static member Create
        (
            patterns: seq<string>,
            ?dictionaries: IReadOnlyDictionary<string, ResizeArray<string>>
        ) =
        Wildling(patterns, dictionaries)

    member _.Index() = internalIndex
    member _.Count() = patternCount
    member _.Reset() = internalIndex <- 0
    member _.Generators() = generatorsList :> IReadOnlyList<_>

    /// Next combination, or false when exhausted.
    member this.Next() : obj =
        if internalIndex = patternCount then
            box false
        else
            internalIndex <- internalIndex + 1
            this.Get(internalIndex - 1)

    /// Combination at index, or false if out of range.
    member _.Get(index: int) : obj =
        if index > patternCount - 1 || index < 0 then
            box false
        else
            let mutable segmentIndex = 0
            let mutable result: obj = box false
            let mutable found = false
            for generator in generatorsList do
                if not found then
                    let patternIndex = index - segmentIndex
                    if patternIndex < generator.Count() then
                        result <- box (generator.Get(patternIndex))
                        found <- true
                    else
                        segmentIndex <- segmentIndex + generator.Count()
            result
