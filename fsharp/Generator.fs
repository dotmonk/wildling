namespace WildlingLib

open System.Collections.Generic

type Generator(inputPattern: string, dictionaries: IReadOnlyDictionary<string, ResizeArray<string>> option) =
    let tokens = ParsePattern.parse inputPattern dictionaries

    let count =
        let mutable total = 1
        for token in tokens do
            total <- total * token.Count()
        total

    member _.Source = inputPattern
    member _.Count() = count
    member _.Tokens() = tokens :> IReadOnlyList<_>

    member _.Get(index: int) =
        if index > count - 1 || index < 0 then
            ""
        else
            let parts = Array.zeroCreate<string> tokens.Count
            let mutable indexWithOffset = index
            for i = 0 to tokens.Count - 1 do
                let token = tokens.[i]
                parts.[i] <- token.Get(indexWithOffset % token.Count())
                indexWithOffset <- indexWithOffset / token.Count()
            String.concat "" parts
