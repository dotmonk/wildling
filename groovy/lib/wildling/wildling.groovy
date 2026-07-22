package wildling

class Wildling {
    public static final String VERSION = "2.0.2"

    private final List<Generator> generators
    private final int patternCount
    private int internalIndex

    Wildling(List<String> patterns, Map<String, List<String>> dictionaries) {
        Map<String, List<String>> dicts = dictionaries != null
                ? dictionaries
                : [:]
        this.generators = new ArrayList<>()
        int total = 0
        if (patterns != null) {
            for (String pattern : patterns) {
                Generator generator = new Generator(pattern, dicts)
                generators.add(generator)
                total += generator.count()
            }
        }
        this.patternCount = total
        this.internalIndex = 0
    }

    static Wildling create(List<String> patterns, Map<String, List<String>> dictionaries) {
        return new Wildling(patterns, dictionaries)
    }

    static Wildling create(List<String> patterns) {
        return new Wildling(patterns, new LinkedHashMap<>())
    }

    static Wildling createWildling(List patterns, Map dictionaries = null) {
        return create(patterns as List<String>, dictionaries as Map<String, List<String>>)
    }

    int index() {
        return internalIndex
    }

    int count() {
        return patternCount
    }

    void reset() {
        internalIndex = 0
    }

    /** Next combination, or {@code Boolean.FALSE} when exhausted. */
    Object next() {
        if (internalIndex == patternCount) {
            return Boolean.FALSE
        }
        internalIndex += 1
        return get(internalIndex - 1)
    }

    List<Generator> generators() {
        return generators
    }

    /** Combination at index, or {@code Boolean.FALSE} if out of range. */
    Object get(int index) {
        if (index > patternCount - 1 || index < 0) {
            return Boolean.FALSE
        }
        int segmentIndex = 0
        for (Generator generator : generators) {
            int patternIndex = index - segmentIndex
            if (patternIndex < generator.count()) {
                return generator.get(patternIndex)
            }
            segmentIndex += generator.count()
        }
        return Boolean.FALSE
    }
}
