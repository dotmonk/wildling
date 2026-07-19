using System.Text.RegularExpressions;

namespace WildlingLib;

public static class ParsePattern
{
    private static readonly Regex TokenParsingRegex = new(
        @"(\\[%@$*#&?!-]|[%@$*#&?!-]\{.*?\}|[%@$*#&?!-])",
        RegexOptions.Compiled);

    private static readonly Regex LengthWithVariants = new(
        @"\{((\d+)-(\d+)|(\d+))\}",
        RegexOptions.Compiled);

    private static readonly Regex LengthWithString = new(
        @"\{'(.*)'(?:,(\d+)-(\d+))?(?:,(\d+))?\}",
        RegexOptions.Compiled);

    private static TokenOptions ParseLengthWithVariants(string part, List<string> variants)
    {
        var match = LengthWithVariants.Match(part);
        var startLength = 1;
        var endLength = 1;

        if (match.Success)
        {
            if (match.Groups[2].Success && match.Groups[2].Value.Length > 0)
            {
                startLength = int.Parse(match.Groups[2].Value);
                endLength = int.Parse(match.Groups[3].Value);
            }
            else if (match.Groups[1].Success)
            {
                startLength = int.Parse(match.Groups[1].Value);
                endLength = startLength;
            }
        }

        return TokenOptions.Of(variants, startLength, endLength, part);
    }

    private static TokenOptions? ParseLengthWithString(string part)
    {
        var match = LengthWithString.Match(part);
        if (!match.Success)
        {
            return null;
        }

        if (match.Groups[2].Success && match.Groups[3].Success)
        {
            return new TokenOptions
            {
                String = match.Groups[1].Value,
                StartLength = int.Parse(match.Groups[2].Value),
                EndLength = int.Parse(match.Groups[3].Value),
                Src = part,
            };
        }

        if (match.Groups[4].Success)
        {
            var length = int.Parse(match.Groups[4].Value);
            return new TokenOptions
            {
                String = match.Groups[1].Value,
                StartLength = length,
                EndLength = length,
                Src = part,
            };
        }

        return new TokenOptions
        {
            String = match.Groups[1].Value,
            StartLength = 1,
            EndLength = 1,
            Src = part,
        };
    }

    private static Func<string, Token> SimpleTokenizer(string variantsString)
    {
        var variants = variantsString.Select(c => c.ToString()).ToList();
        return part => new Token(ParseLengthWithVariants(part, variants));
    }

    private static Token DictionaryTokenizer(string part, IReadOnlyDictionary<string, List<string>> dictionaries)
    {
        var options = ParseLengthWithString(part);
        if (options is null
            || (!string.IsNullOrEmpty(options.String) && !dictionaries.ContainsKey(options.String)))
        {
            return new Token(TokenOptions.Of(new List<string> { part }, 1, 1, part));
        }

        options.Variants = dictionaries.TryGetValue(options.String ?? "", out var words)
            ? words
            : new List<string>();
        return new Token(options);
    }

    private static Token WordsTokenizer(string part)
    {
        var options = ParseLengthWithString(part);
        if (options is null)
        {
            return new Token(TokenOptions.Of(new List<string> { part }, 1, 1, part));
        }

        var variants = new List<string>();
        var workString = options.String ?? "";
        var index = 0;
        while (index < workString.Length)
        {
            if (index + 1 < workString.Length
                && workString[index] == '\\'
                && workString[index + 1] == ',')
            {
                index += 2;
            }
            else if (workString[index] == ',')
            {
                variants.Add(workString[..index]);
                workString = workString[(index + 1)..];
                index = 0;
            }
            else
            {
                index += 1;
            }
        }
        variants.Add(workString);
        options.Variants = variants.Select(v => v.Replace("\\,", ",")).ToList();
        return new Token(options);
    }

    private static Token PartToToken(string part, IReadOnlyDictionary<string, List<string>> dictionaries)
    {
        var tokenizers = new Dictionary<char, Func<string, Token>>
        {
            ['#'] = SimpleTokenizer("0123456789"),
            ['@'] = SimpleTokenizer("abcdefghijklmnopqrstuvwxyz"),
            ['*'] = SimpleTokenizer("abcdefghijklmnopqrstuvwxyz0123456789"),
            ['-'] = SimpleTokenizer("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"),
            ['!'] = SimpleTokenizer("ABCDEFGHIJKLMNOPQRSTUVWXYZ"),
            ['?'] = SimpleTokenizer("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"),
            ['&'] = SimpleTokenizer("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"),
            ['%'] = p => DictionaryTokenizer(p, dictionaries),
            ['$'] = WordsTokenizer,
        };

        Func<string, Token>? tokenizer = part.Length > 0 && tokenizers.TryGetValue(part[0], out var t)
            ? t
            : null;
        var isEscapedToken = part.Length > 1 && part[0] == '\\' && tokenizers.ContainsKey(part[1]);

        if (tokenizer is not null)
        {
            return tokenizer(part);
        }

        if (isEscapedToken)
        {
            return new Token(TokenOptions.Of(new List<string> { part[1..] }, 1, 1, part));
        }

        return new Token(TokenOptions.Of(new List<string> { part }, 1, 1, part));
    }

    public static List<Token> Parse(string inputPattern, IReadOnlyDictionary<string, List<string>>? dictionaries)
    {
        var dicts = dictionaries ?? new Dictionary<string, List<string>>();
        // Capturing groups are included in .NET Regex.Split results (like JS/Python).
        var parts = TokenParsingRegex.Split(inputPattern).Where(p => p.Length > 0);
        return parts.Select(part => PartToToken(part, dicts)).ToList();
    }
}
