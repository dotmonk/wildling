namespace WildlingLib;

public sealed class Wildling
{
    public const string Version = "2.0.3";

    private readonly List<Generator> _generators;
    private readonly int _patternCount;
    private int _internalIndex;

    public Wildling(IEnumerable<string> patterns, IReadOnlyDictionary<string, List<string>>? dictionaries = null)
    {
        var dicts = dictionaries ?? new Dictionary<string, List<string>>();
        _generators = new List<Generator>();
        var total = 0;
        foreach (var pattern in patterns)
        {
            var generator = new Generator(pattern, dicts);
            _generators.Add(generator);
            total += generator.Count();
        }
        _patternCount = total;
        _internalIndex = 0;
    }

    public static Wildling Create(
        IEnumerable<string> patterns,
        IReadOnlyDictionary<string, List<string>>? dictionaries = null) =>
        new(patterns, dictionaries);

    public int Index() => _internalIndex;

    public int Count() => _patternCount;

    public void Reset() => _internalIndex = 0;

    /// <summary>Next combination, or <c>false</c> when exhausted.</summary>
    public object Next()
    {
        if (_internalIndex == _patternCount)
        {
            return false;
        }
        _internalIndex += 1;
        return Get(_internalIndex - 1);
    }

    public IReadOnlyList<Generator> Generators() => _generators;

    /// <summary>Combination at index, or <c>false</c> if out of range.</summary>
    public object Get(int index)
    {
        if (index > _patternCount - 1 || index < 0)
        {
            return false;
        }

        var segmentIndex = 0;
        foreach (var generator in _generators)
        {
            var patternIndex = index - segmentIndex;
            if (patternIndex < generator.Count())
            {
                return generator.Get(patternIndex);
            }
            segmentIndex += generator.Count();
        }
        return false;
    }
}
