package wildling

class Generator {
    private final String source
    private final List<Token> tokens
    private final int count

    Generator(String inputPattern, Map<String, List<String>> dictionaries) {
        this.source = inputPattern
        this.tokens = ParsePattern.parse(inputPattern, dictionaries)
        int total = 1
        for (Token token : tokens) {
            total *= token.count()
        }
        this.count = total
    }

    String source() {
        return source
    }

    int count() {
        return count
    }

    List<Token> tokens() {
        return tokens
    }

    String get(int index) {
        if (index > count - 1 || index < 0) {
            return ""
        }
        def out = new StringBuilder()
        int indexWithOffset = index
        for (Token token : tokens) {
            out.append(token.get(indexWithOffset % token.count()))
            indexWithOffset = indexWithOffset.intdiv(token.count())
        }
        return out.toString()
    }
}
