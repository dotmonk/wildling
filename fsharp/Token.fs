namespace WildlingLib

open System.Collections.Generic

type TokenOptions =
    { mutable String: string option
      mutable StartLength: int option
      mutable EndLength: int option
      mutable Variants: ResizeArray<string> option
      mutable Src: string }

module TokenOptions =
    let ofVariants (variants: ResizeArray<string>) startLength endLength src =
        { String = None
          StartLength = Some startLength
          EndLength = Some endLength
          Variants = Some variants
          Src = src }

type Token(options: TokenOptions) =
    let src = if isNull options.Src then "" else options.Src

    let defaultInteger (option: int option) fallback =
        match option with
        | Some v when v >= 0 -> v
        | _ -> fallback

    let startLength = defaultInteger options.StartLength 1
    let endLength = defaultInteger options.EndLength 1

    let variants =
        match options.Variants with
        | Some v -> ResizeArray<string>(v)
        | None -> ResizeArray<string>()

    let pow baseValue exp =
        let mutable result = 1
        for _ = 1 to exp do
            result <- result * baseValue
        result

    let count =
        let mutable total = 0
        for length = startLength to endLength do
            total <- total + pow variants.Count length
        total

    member _.Count() = count
    member _.Src() = src

    member _.Get(index: int) =
        if index > count - 1 || index < 0 then
            ""
        elif index = 0 && startLength = 0 then
            ""
        else
            let mutable indexWithOffset = index
            let mutable stringLength = startLength
            let mutable found = false
            let mutable length = startLength
            while length <= endLength && not found do
                let offsetCount = pow variants.Count length
                if indexWithOffset < offsetCount then
                    stringLength <- length
                    found <- true
                else
                    indexWithOffset <- indexWithOffset - offsetCount
                    length <- length + 1

            let chars = Array.zeroCreate<string> stringLength
            for i = 0 to stringLength - 1 do
                let variantIndex = indexWithOffset % variants.Count
                indexWithOffset <- indexWithOffset / variants.Count
                chars.[i] <- variants.[variantIndex]
            String.concat "" chars
