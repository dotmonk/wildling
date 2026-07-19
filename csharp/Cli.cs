using System.Text;
using System.Text.Json;

namespace WildlingLib;

public static class Cli
{
    internal sealed class Range
    {
        public Range(int start, int end)
        {
            Start = start;
            End = end;
        }

        public int Start { get; }
        public int End { get; }
    }

    internal sealed class CliArgs
    {
        public List<int> Selects { get; } = new();
        public List<Range> Ranges { get; } = new();
        public bool Check { get; set; }
        public Dictionary<string, List<string>> Dictionaries { get; } = new();
        public List<string> Patterns { get; } = new();
        public bool Help { get; set; }
        public bool Version { get; set; }
    }

    internal static Range? ParseRange(string value)
    {
        var dash = value.IndexOf('-');
        if (dash <= 0 || dash == value.Length - 1)
        {
            return null;
        }
        if (!int.TryParse(value[..dash], out var start) || !int.TryParse(value[(dash + 1)..], out var end))
        {
            return null;
        }
        return start <= end ? new Range(start, end) : null;
    }

    internal static List<string> LoadDictionaryFile(string path) =>
        File.ReadAllLines(path, Encoding.UTF8)
            .Select(l => l.Trim())
            .Where(l => l.Length > 0)
            .ToList();

    internal static void ApplyDictionary(CliArgs result, string name, object? value)
    {
        if (value is JsonElement json)
        {
            if (json.ValueKind == JsonValueKind.Array)
            {
                var words = new List<string>();
                foreach (var item in json.EnumerateArray())
                {
                    words.Add(item.ToString());
                }
                result.Dictionaries[name] = words;
                return;
            }

            if (json.ValueKind == JsonValueKind.String)
            {
                value = json.GetString();
            }
            else
            {
                return;
            }
        }

        if (value is List<object> list)
        {
            result.Dictionaries[name] = list.Select(v => v?.ToString() ?? "").ToList();
            return;
        }

        var path = value?.ToString();
        if (!string.IsNullOrEmpty(path) && File.Exists(path))
        {
            try
            {
                result.Dictionaries[name] = LoadDictionaryFile(path);
            }
            catch (IOException)
            {
                // ignore unreadable dictionary files
            }
        }
    }

    internal static void ApplyTemplate(CliArgs result, string path)
    {
        if (!File.Exists(path))
        {
            Console.Error.WriteLine($"Template file not found: {path}");
            Environment.Exit(1);
        }

        JsonDocument document;
        try
        {
            document = JsonDocument.Parse(File.ReadAllText(path, Encoding.UTF8));
        }
        catch (Exception)
        {
            Console.Error.WriteLine($"Invalid JSON template: {path}");
            Environment.Exit(1);
            return;
        }

        using (document)
        {
            if (document.RootElement.ValueKind != JsonValueKind.Object)
            {
                Console.Error.WriteLine($"Invalid JSON template: {path}");
                Environment.Exit(1);
            }

            var root = document.RootElement;

            if (root.TryGetProperty("check", out var check) && check.ValueKind == JsonValueKind.True)
            {
                result.Check = true;
            }

            if (root.TryGetProperty("select", out var select) && select.ValueKind == JsonValueKind.Array)
            {
                foreach (var val in select.EnumerateArray())
                {
                    int number;
                    if (val.ValueKind == JsonValueKind.Number && val.TryGetInt32(out number))
                    {
                        if (number >= 0) result.Selects.Add(number);
                    }
                    else if (int.TryParse(val.ToString(), out number) && number >= 0)
                    {
                        result.Selects.Add(number);
                    }
                }
            }

            if (root.TryGetProperty("range", out var ranges) && ranges.ValueKind == JsonValueKind.Array)
            {
                foreach (var rangeStr in ranges.EnumerateArray())
                {
                    var parsed = ParseRange(rangeStr.ToString());
                    if (parsed is not null)
                    {
                        result.Ranges.Add(parsed);
                    }
                }
            }

            if (root.TryGetProperty("dictionaries", out var dictionaries)
                && dictionaries.ValueKind == JsonValueKind.Object)
            {
                foreach (var entry in dictionaries.EnumerateObject())
                {
                    ApplyDictionary(result, entry.Name, entry.Value);
                }
            }

            if (root.TryGetProperty("patterns", out var patterns) && patterns.ValueKind == JsonValueKind.Array)
            {
                foreach (var pattern in patterns.EnumerateArray())
                {
                    result.Patterns.Add(pattern.ToString());
                }
            }
        }
    }

    internal static CliArgs ParseArgs(string[] args)
    {
        var result = new CliArgs();
        var i = 0;
        while (i < args.Length)
        {
            var arg = args[i];

            if (arg is "--help" or "-h")
            {
                result.Help = true;
                i++;
                continue;
            }

            if (arg is "--version" or "-v")
            {
                result.Version = true;
                i++;
                continue;
            }

            if (arg == "--check")
            {
                result.Check = true;
                i++;
                continue;
            }

            if (arg == "--select")
            {
                i++;
                if (i >= args.Length) break;
                if (int.TryParse(args[i], out var val) && val >= 0)
                {
                    result.Selects.Add(val);
                }
                i++;
                continue;
            }

            if (arg == "--range")
            {
                i++;
                if (i >= args.Length) break;
                var parsed = ParseRange(args[i]);
                if (parsed is not null)
                {
                    result.Ranges.Add(parsed);
                }
                i++;
                continue;
            }

            if (arg == "--dictionary")
            {
                i++;
                if (i >= args.Length) break;
                var spec = args[i];
                var colon = spec.IndexOf(':');
                if (colon > 0 && colon < spec.Length - 1)
                {
                    ApplyDictionary(result, spec[..colon], spec[(colon + 1)..]);
                }
                i++;
                continue;
            }

            if (arg == "--template")
            {
                i++;
                if (i >= args.Length)
                {
                    Console.Error.WriteLine("Missing path for --template");
                    Environment.Exit(1);
                }
                ApplyTemplate(result, args[i]);
                i++;
                continue;
            }

            result.Patterns.Add(arg);
            i++;
        }

        return result;
    }

    internal static string LoadHelpText()
    {
        var candidates = new[]
        {
            Path.Combine(AppContext.BaseDirectory, "help.txt"),
            Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "help.txt"),
            Path.Combine("docs", "help.txt"),
        };

        foreach (var path in candidates)
        {
            if (File.Exists(path))
            {
                return File.ReadAllText(path, Encoding.UTF8);
            }
        }

        return "wildling - pattern based string generator\n\nHelp text unavailable.\n";
    }

    internal static string FormatList(IEnumerable<object> values)
    {
        var list = values.ToList();
        return list.Count == 0 ? "" : " " + string.Join(" ", list);
    }

    internal static string FormatCheckOutput(CliArgs args, int total, IReadOnlyList<Generator> generators)
    {
        var lines = new List<string>
        {
            $"patterns:{FormatList(args.Patterns)}",
            $"dictionaries:{FormatList(args.Dictionaries.Keys)}",
            $"select:{FormatList(args.Selects.Cast<object>())}",
            $"range:{FormatList(args.Ranges.Select(r => $"{r.Start}-{r.End}"))}",
            $"total: {total}",
        };
        foreach (var gen in generators)
        {
            lines.Add($"generator: {gen.Source} {gen.Count()}");
        }
        return string.Join("\n", lines);
    }

    /// <summary>Print a result; out-of-range sentinel is lowercase false.</summary>
    internal static void WriteResult(object value)
    {
        if (value is false)
        {
            Console.WriteLine("false");
        }
        else
        {
            Console.WriteLine(value);
        }
    }

    public static int Run(string[] args)
    {
        var parsed = ParseArgs(args);

        if (parsed.Help)
        {
            Console.WriteLine(LoadHelpText().TrimEnd());
            return 0;
        }

        if (parsed.Version)
        {
            Console.WriteLine($"wildling {Wildling.Version}");
            return 0;
        }

        if (parsed.Patterns.Count == 0)
        {
            Console.Error.WriteLine("No pattern provided. Use --help for usage information.");
            return 1;
        }

        var wildcard = Wildling.Create(parsed.Patterns, parsed.Dictionaries);

        if (parsed.Check)
        {
            Console.WriteLine(FormatCheckOutput(parsed, wildcard.Count(), wildcard.Generators()));
            return 0;
        }

        if (parsed.Selects.Count > 0 || parsed.Ranges.Count > 0)
        {
            foreach (var index in parsed.Selects)
            {
                WriteResult(wildcard.Get(index));
            }
            foreach (var range in parsed.Ranges)
            {
                for (var index = range.Start; index <= range.End; index++)
                {
                    WriteResult(wildcard.Get(index));
                }
            }
            return 0;
        }

        var value = wildcard.Next();
        while (value is not false)
        {
            Console.WriteLine(value);
            value = wildcard.Next();
        }

        return 0;
    }
}
