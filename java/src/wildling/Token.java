package wildling;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

final class TokenOptions {
    String string;
    Integer startLength;
    Integer endLength;
    List<String> variants;
    String src;

    TokenOptions() {}

    static TokenOptions of(
            List<String> variants,
            Integer startLength,
            Integer endLength,
            String src
    ) {
        TokenOptions options = new TokenOptions();
        options.variants = variants;
        options.startLength = startLength;
        options.endLength = endLength;
        options.src = src;
        return options;
    }
}

public final class Token {
    private final String src;
    private final int startLength;
    private final int endLength;
    private final List<String> variants;
    private final int count;

    public Token(TokenOptions options) {
        this.src = options.src != null ? options.src : "";
        this.startLength = defaultInteger(options.startLength, 1);
        this.endLength = defaultInteger(options.endLength, 1);
        this.variants = options.variants != null
                ? new ArrayList<>(options.variants)
                : Collections.emptyList();

        int total = 0;
        for (int length = this.startLength; length <= this.endLength; length++) {
            total += pow(this.variants.size(), length);
        }
        this.count = total;
    }

    private static int defaultInteger(Integer option, int fallback) {
        return option != null && option >= 0 ? option : fallback;
    }

    private static int pow(int base, int exp) {
        int result = 1;
        for (int i = 0; i < exp; i++) {
            result *= base;
        }
        return result;
    }

    public int count() {
        return count;
    }

    public String src() {
        return src;
    }

    public String get(int index) {
        if (index > count - 1 || index < 0) {
            return "";
        }
        if (index == 0 && startLength == 0) {
            return "";
        }

        int indexWithOffset = index;
        int stringLength = startLength;
        for (stringLength = startLength; stringLength <= endLength; stringLength++) {
            int offsetCount = pow(variants.size(), stringLength);
            if (indexWithOffset < offsetCount) {
                break;
            }
            indexWithOffset -= offsetCount;
        }

        StringBuilder out = new StringBuilder();
        for (int i = 0; i < stringLength; i++) {
            int variantIndex = indexWithOffset % variants.size();
            indexWithOffset /= variants.size();
            out.append(variants.get(variantIndex));
        }
        return out.toString();
    }
}
