namespace WildlingLib

open System.Collections.Generic
open System.Text.RegularExpressions

module ParsePattern =
    let private tokenParsingRegex =
        Regex(@"(\\[%@$*#&?!-]|[%@$*#&?!-]\{.*?\}|[%@$*#&?!-])", RegexOptions.Compiled)

    let private lengthWithVariants =
        Regex(@"\{((\d+)-(\d+)|(\d+))\}", RegexOptions.Compiled)

    let private lengthWithString =
        Regex(@"\{'(.*)'(?:,(\d+)-(\d+))?(?:,(\d+))?\}", RegexOptions.Compiled)

    let private parseLengthWithVariants (part: string) (variants: ResizeArray<string>) =
        let m = lengthWithVariants.Match(part)
        let mutable startLength = 1
        let mutable endLength = 1

        if m.Success then
            if m.Groups.[2].Success && m.Groups.[2].Value.Length > 0 then
                startLength <- int m.Groups.[2].Value
                endLength <- int m.Groups.[3].Value
            elif m.Groups.[1].Success then
                startLength <- int m.Groups.[1].Value
                endLength <- startLength

        TokenOptions.ofVariants variants startLength endLength part

    let private parseLengthWithString (part: string) =
        let m = lengthWithString.Match(part)
        if not m.Success then
            None
        elif m.Groups.[2].Success && m.Groups.[3].Success then
            Some
                { String = Some m.Groups.[1].Value
                  StartLength = Some(int m.Groups.[2].Value)
                  EndLength = Some(int m.Groups.[3].Value)
                  Variants = None
                  Src = part }
        elif m.Groups.[4].Success then
            let length = int m.Groups.[4].Value
            Some
                { String = Some m.Groups.[1].Value
                  StartLength = Some length
                  EndLength = Some length
                  Variants = None
                  Src = part }
        else
            Some
                { String = Some m.Groups.[1].Value
                  StartLength = Some 1
                  EndLength = Some 1
                  Variants = None
                  Src = part }

    let private simpleTokenizer (variantsString: string) =
        let variants =
            ResizeArray<string>(variantsString |> Seq.map string)
        fun (part: string) -> Token(parseLengthWithVariants part variants)

    let private dictionaryTokenizer
        (part: string)
        (dictionaries: IReadOnlyDictionary<string, ResizeArray<string>>)
        =
        match parseLengthWithString part with
        | None ->
            Token(TokenOptions.ofVariants (ResizeArray([ part ])) 1 1 part)
        | Some options ->
            let key = defaultArg options.String ""
            if key <> "" && not (dictionaries.ContainsKey(key)) then
                Token(TokenOptions.ofVariants (ResizeArray([ part ])) 1 1 part)
            else
                match dictionaries.TryGetValue(key) with
                | true, words -> options.Variants <- Some words
                | false, _ -> options.Variants <- Some(ResizeArray())
                Token(options)

    let private wordsTokenizer (part: string) =
        match parseLengthWithString part with
        | None ->
            Token(TokenOptions.ofVariants (ResizeArray([ part ])) 1 1 part)
        | Some options ->
            let variants = ResizeArray<string>()
            let mutable workString = defaultArg options.String ""
            let mutable index = 0
            while index < workString.Length do
                if
                    index + 1 < workString.Length
                    && workString.[index] = '\\'
                    && workString.[index + 1] = ','
                then
                    index <- index + 2
                elif workString.[index] = ',' then
                    variants.Add(workString.[.. index - 1])
                    workString <- workString.[index + 1 ..]
                    index <- 0
                else
                    index <- index + 1
            variants.Add(workString)
            options.Variants <-
                Some(ResizeArray(variants |> Seq.map (fun v -> v.Replace("\\,", ","))))
            Token(options)

    let private partToToken
        (part: string)
        (dictionaries: IReadOnlyDictionary<string, ResizeArray<string>>)
        =
        let tokenizers =
            dict
                [ '#', simpleTokenizer "0123456789"
                  '@', simpleTokenizer "abcdefghijklmnopqrstuvwxyz"
                  '*', simpleTokenizer "abcdefghijklmnopqrstuvwxyz0123456789"
                  '-', simpleTokenizer "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
                  '!', simpleTokenizer "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
                  '?', simpleTokenizer "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
                  '&', simpleTokenizer "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
                  '%', (fun p -> dictionaryTokenizer p dictionaries)
                  '$', wordsTokenizer ]

        let tokenizer =
            if part.Length > 0 then
                match tokenizers.TryGetValue(part.[0]) with
                | true, t -> Some t
                | false, _ -> None
            else
                None

        let isEscapedToken =
            part.Length > 1
            && part.[0] = '\\'
            && tokenizers.ContainsKey(part.[1])

        match tokenizer with
        | Some t -> t part
        | None when isEscapedToken ->
            Token(TokenOptions.ofVariants (ResizeArray([ part.[1..] ])) 1 1 part)
        | None ->
            Token(TokenOptions.ofVariants (ResizeArray([ part ])) 1 1 part)

    let parse
        (inputPattern: string)
        (dictionaries: IReadOnlyDictionary<string, ResizeArray<string>> option)
        =
        let dicts =
            defaultArg
                dictionaries
                (Dictionary<string, ResizeArray<string>>() :> IReadOnlyDictionary<_, _>)
        // Capturing groups are included in .NET Regex.Split results (like JS/Python).
        tokenParsingRegex.Split(inputPattern)
        |> Seq.filter (fun p -> p.Length > 0)
        |> Seq.map (fun part -> partToToken part dicts)
        |> ResizeArray
