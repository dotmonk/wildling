namespace WildlingLib

open System
open System.Collections.Generic
open System.IO
open System.Text
open System.Text.Json

module Cli =
    type Range = { Start: int; End: int }

    type CliArgs =
        { Selects: ResizeArray<int>
          Ranges: ResizeArray<Range>
          mutable Check: bool
          Dictionaries: Dictionary<string, ResizeArray<string>>
          Patterns: ResizeArray<string>
          mutable Help: bool
          mutable Version: bool }

    let private createArgs () =
        { Selects = ResizeArray()
          Ranges = ResizeArray()
          Check = false
          Dictionaries = Dictionary()
          Patterns = ResizeArray()
          Help = false
          Version = false }

    let parseRange (value: string) =
        let dash = value.IndexOf('-')
        if dash <= 0 || dash = value.Length - 1 then
            None
        else
            match Int32.TryParse(value.[.. dash - 1]), Int32.TryParse(value.[dash + 1 ..]) with
            | (true, start), (true, end') when start <= end' -> Some { Start = start; End = end' }
            | _ -> None

    let loadDictionaryFile (path: string) =
        File.ReadAllLines(path, Encoding.UTF8)
        |> Seq.map (fun l -> l.Trim())
        |> Seq.filter (fun l -> l.Length > 0)
        |> ResizeArray

    let rec applyDictionary (result: CliArgs) (name: string) (value: obj) =
        match value with
        | :? JsonElement as json when json.ValueKind = JsonValueKind.Array ->
            let words = ResizeArray<string>()
            for item in json.EnumerateArray() do
                words.Add(item.ToString())
            result.Dictionaries.[name] <- words
        | :? JsonElement as json when json.ValueKind = JsonValueKind.String ->
            applyDictionary result name (box (json.GetString()))
        | :? JsonElement -> ()
        | :? ResizeArray<obj> as list ->
            result.Dictionaries.[name] <-
                ResizeArray(list |> Seq.map (fun v -> if isNull v then "" else v.ToString()))
        | _ ->
            let path = if isNull value then null else value.ToString()
            if not (String.IsNullOrEmpty(path)) && File.Exists(path) then
                try
                    result.Dictionaries.[name] <- loadDictionaryFile path
                with :? IOException ->
                    ()

    let applyTemplate (result: CliArgs) (path: string) =
        if not (File.Exists(path)) then
            eprintfn "Template file not found: %s" path
            Environment.Exit(1)

        let document =
            try
                JsonDocument.Parse(File.ReadAllText(path, Encoding.UTF8))
            with _ ->
                eprintfn "Invalid JSON template: %s" path
                Environment.Exit(1)
                Unchecked.defaultof<_>

        use _ = document
        if document.RootElement.ValueKind <> JsonValueKind.Object then
            eprintfn "Invalid JSON template: %s" path
            Environment.Exit(1)

        let root = document.RootElement

        match root.TryGetProperty("check") with
        | true, check when check.ValueKind = JsonValueKind.True -> result.Check <- true
        | _ -> ()

        match root.TryGetProperty("select") with
        | true, select when select.ValueKind = JsonValueKind.Array ->
            for val' in select.EnumerateArray() do
                match val'.ValueKind with
                | JsonValueKind.Number ->
                    match val'.TryGetInt32() with
                    | true, number when number >= 0 -> result.Selects.Add(number)
                    | _ -> ()
                | _ ->
                    match Int32.TryParse(val'.ToString()) with
                    | true, number when number >= 0 -> result.Selects.Add(number)
                    | _ -> ()
        | _ -> ()

        match root.TryGetProperty("range") with
        | true, ranges when ranges.ValueKind = JsonValueKind.Array ->
            for rangeStr in ranges.EnumerateArray() do
                match parseRange (rangeStr.ToString()) with
                | Some parsed -> result.Ranges.Add(parsed)
                | None -> ()
        | _ -> ()

        match root.TryGetProperty("dictionaries") with
        | true, dictionaries when dictionaries.ValueKind = JsonValueKind.Object ->
            for entry in dictionaries.EnumerateObject() do
                applyDictionary result entry.Name (box entry.Value)
        | _ -> ()

        match root.TryGetProperty("patterns") with
        | true, patterns when patterns.ValueKind = JsonValueKind.Array ->
            for pattern in patterns.EnumerateArray() do
                result.Patterns.Add(pattern.ToString())
        | _ -> ()

    let parseArgs (args: string[]) =
        let result = createArgs ()
        let mutable i = 0
        while i < args.Length do
            let arg = args.[i]
            match arg with
            | "--help"
            | "-h" ->
                result.Help <- true
                i <- i + 1
            | "--version"
            | "-v" ->
                result.Version <- true
                i <- i + 1
            | "--check" ->
                result.Check <- true
                i <- i + 1
            | "--select" ->
                i <- i + 1
                if i < args.Length then
                    match Int32.TryParse(args.[i]) with
                    | true, value when value >= 0 -> result.Selects.Add(value)
                    | _ -> ()
                    i <- i + 1
            | "--range" ->
                i <- i + 1
                if i < args.Length then
                    match parseRange args.[i] with
                    | Some parsed -> result.Ranges.Add(parsed)
                    | None -> ()
                    i <- i + 1
            | "--dictionary" ->
                i <- i + 1
                if i < args.Length then
                    let spec = args.[i]
                    let colon = spec.IndexOf(':')
                    if colon > 0 && colon < spec.Length - 1 then
                        applyDictionary result spec.[.. colon - 1] (box spec.[colon + 1 ..])
                    i <- i + 1
            | "--template" ->
                i <- i + 1
                if i >= args.Length then
                    eprintfn "Missing path for --template"
                    Environment.Exit(1)
                applyTemplate result args.[i]
                i <- i + 1
            | _ ->
                result.Patterns.Add(arg)
                i <- i + 1
        result

    let loadHelpText () =
        let candidates =
            [| Path.Combine(AppContext.BaseDirectory, "help.txt")
               Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "help.txt")
               Path.Combine("docs", "help.txt") |]

        candidates
        |> Array.tryFind File.Exists
        |> Option.map (fun path -> File.ReadAllText(path, Encoding.UTF8))
        |> Option.defaultValue "wildling - pattern based string generator\n\nHelp text unavailable.\n"

    let formatList (values: seq<obj>) =
        let list = ResizeArray(values)
        if list.Count = 0 then
            ""
        else
            " " + String.Join(" ", list)

    let formatCheckOutput (args: CliArgs) total (generators: IReadOnlyList<Generator>) =
        let lines =
            ResizeArray(
                [ sprintf "patterns:%s" (formatList (args.Patterns |> Seq.map box))
                  sprintf "dictionaries:%s" (formatList (args.Dictionaries.Keys |> Seq.map box))
                  sprintf "select:%s" (formatList (args.Selects |> Seq.map box))
                  sprintf
                      "range:%s"
                      (formatList (args.Ranges |> Seq.map (fun r -> box $"{r.Start}-{r.End}")))
                  sprintf "total: %d" total ]
            )
        for gen in generators do
            lines.Add(sprintf "generator: %s %d" gen.Source (gen.Count()))
        String.Join("\n", lines)

    let private isFalse (value: obj) =
        match value with
        | :? bool as b -> b = false
        | _ -> false

    /// Print a result; out-of-range sentinel is lowercase false.
    let private printResult (value: obj) =
        if isFalse value then printfn "false" else printfn "%O" value

    let run (args: string[]) =
        let parsed = parseArgs args

        if parsed.Help then
            printfn "%s" (loadHelpText().TrimEnd())
            0
        elif parsed.Version then
            printfn "wildling %s" Wildling.Version
            0
        elif parsed.Patterns.Count = 0 then
            eprintfn "No pattern provided. Use --help for usage information."
            1
        else
            let dictionaries =
                parsed.Dictionaries :> IReadOnlyDictionary<string, ResizeArray<string>>
            let wildcard = Wildling.Create(parsed.Patterns, dictionaries)

            if parsed.Check then
                printfn "%s" (formatCheckOutput parsed (wildcard.Count()) (wildcard.Generators()))
                0
            elif parsed.Selects.Count > 0 || parsed.Ranges.Count > 0 then
                for index in parsed.Selects do
                    printResult (wildcard.Get(index))
                for range in parsed.Ranges do
                    for index = range.Start to range.End do
                        printResult (wildcard.Get(index))
                0
            else
                let mutable value = wildcard.Next()
                while not (isFalse value) do
                    printfn "%O" value
                    value <- wildcard.Next()
                0
