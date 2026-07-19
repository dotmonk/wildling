namespace WildlingLib;

public sealed class Generator
{
    private readonly List<Token> _tokens;
    private readonly int _count;

    public Generator(string inputPattern, IReadOnlyDictionary<string, List<string>>? dictionaries)
    {
        Source = inputPattern;
        _tokens = ParsePattern.Parse(inputPattern, dictionaries);
        var total = 1;
        foreach (var token in _tokens)
        {
            total *= token.Count();
        }
        _count = total;
    }

    public string Source { get; }

    public int Count() => _count;

    public IReadOnlyList<Token> Tokens() => _tokens;

    public string Get(int index)
    {
        if (index > _count - 1 || index < 0)
        {
            return "";
        }

        var parts = new string[_tokens.Count];
        var indexWithOffset = index;
        for (var i = 0; i < _tokens.Count; i++)
        {
            var token = _tokens[i];
            parts[i] = token.Get(indexWithOffset % token.Count());
            indexWithOffset /= token.Count();
        }
        return string.Concat(parts);
    }
}
