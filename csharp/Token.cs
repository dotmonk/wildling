namespace WildlingLib;

public sealed class TokenOptions
{
    public string? String { get; set; }
    public int? StartLength { get; set; }
    public int? EndLength { get; set; }
    public List<string>? Variants { get; set; }
    public string Src { get; set; } = "";

    public static TokenOptions Of(List<string> variants, int startLength, int endLength, string src) =>
        new()
        {
            Variants = variants,
            StartLength = startLength,
            EndLength = endLength,
            Src = src,
        };
}

public sealed class Token
{
    private readonly string _src;
    private readonly int _startLength;
    private readonly int _endLength;
    private readonly List<string> _variants;
    private readonly int _count;

    public Token(TokenOptions options)
    {
        _src = options.Src ?? "";
        _startLength = DefaultInteger(options.StartLength, 1);
        _endLength = DefaultInteger(options.EndLength, 1);
        _variants = options.Variants != null ? new List<string>(options.Variants) : new List<string>();

        var total = 0;
        for (var length = _startLength; length <= _endLength; length++)
        {
            total += Pow(_variants.Count, length);
        }
        _count = total;
    }

    private static int DefaultInteger(int? option, int fallback) =>
        option is >= 0 ? option.Value : fallback;

    private static int Pow(int baseValue, int exp)
    {
        var result = 1;
        for (var i = 0; i < exp; i++)
        {
            result *= baseValue;
        }
        return result;
    }

    public int Count() => _count;

    public string Src() => _src;

    public string Get(int index)
    {
        if (index > _count - 1 || index < 0)
        {
            return "";
        }

        if (index == 0 && _startLength == 0)
        {
            return "";
        }

        var indexWithOffset = index;
        var stringLength = _startLength;
        for (stringLength = _startLength; stringLength <= _endLength; stringLength++)
        {
            var offsetCount = Pow(_variants.Count, stringLength);
            if (indexWithOffset < offsetCount)
            {
                break;
            }
            indexWithOffset -= offsetCount;
        }

        var chars = new string[stringLength];
        for (var i = 0; i < stringLength; i++)
        {
            var variantIndex = indexWithOffset % _variants.Count;
            indexWithOffset /= _variants.Count;
            chars[i] = _variants[variantIndex];
        }
        return string.Concat(chars);
    }
}
