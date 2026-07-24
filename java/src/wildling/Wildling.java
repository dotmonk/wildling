package wildling;

import java.util.ArrayList;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

public final class Wildling {
    public static final String VERSION = "2.0.5";

    private final List<Generator> generators;
    private final int patternCount;
    private int internalIndex;

    public Wildling(List<String> patterns, Map<String, List<String>> dictionaries) {
        Map<String, List<String>> dicts = dictionaries != null
                ? dictionaries
                : Collections.emptyMap();
        this.generators = new ArrayList<>();
        int total = 0;
        if (patterns != null) {
            for (String pattern : patterns) {
                Generator generator = new Generator(pattern, dicts);
                generators.add(generator);
                total += generator.count();
            }
        }
        this.patternCount = total;
        this.internalIndex = 0;
    }

    public static Wildling create(List<String> patterns, Map<String, List<String>> dictionaries) {
        return new Wildling(patterns, dictionaries);
    }

    public static Wildling create(List<String> patterns) {
        return new Wildling(patterns, new LinkedHashMap<>());
    }

    public int index() {
        return internalIndex;
    }

    public int count() {
        return patternCount;
    }

    public void reset() {
        internalIndex = 0;
    }

    /** Next combination, or {@code Boolean.FALSE} when exhausted. */
    public Object next() {
        if (internalIndex == patternCount) {
            return Boolean.FALSE;
        }
        internalIndex += 1;
        return get(internalIndex - 1);
    }

    public List<Generator> generators() {
        return generators;
    }

    /** Combination at index, or {@code Boolean.FALSE} if out of range. */
    public Object get(int index) {
        if (index > patternCount - 1 || index < 0) {
            return Boolean.FALSE;
        }
        int segmentIndex = 0;
        for (Generator generator : generators) {
            int patternIndex = index - segmentIndex;
            if (patternIndex < generator.count()) {
                return generator.get(patternIndex);
            }
            segmentIndex += generator.count();
        }
        return Boolean.FALSE;
    }
}
