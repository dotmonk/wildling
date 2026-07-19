package wildling;

import java.util.List;
import java.util.Map;

public final class Generator {
    private final String source;
    private final List<Token> tokens;
    private final int count;

    public Generator(String inputPattern, Map<String, List<String>> dictionaries) {
        this.source = inputPattern;
        this.tokens = ParsePattern.parse(inputPattern, dictionaries);
        int total = 1;
        for (Token token : tokens) {
            total *= token.count();
        }
        this.count = total;
    }

    public String source() {
        return source;
    }

    public int count() {
        return count;
    }

    public List<Token> tokens() {
        return tokens;
    }

    public String get(int index) {
        if (index > count - 1 || index < 0) {
            return "";
        }
        StringBuilder out = new StringBuilder();
        int indexWithOffset = index;
        for (Token token : tokens) {
            out.append(token.get(indexWithOffset % token.count()));
            indexWithOffset /= token.count();
        }
        return out.toString();
    }
}
