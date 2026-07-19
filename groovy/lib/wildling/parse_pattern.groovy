package wildling

import java.util.function.Function
import java.util.regex.Matcher
import java.util.regex.Pattern

class ParsePattern {
    private static final Pattern TOKEN_PARSING_REGEX = Pattern.compile(
            "(\\\\[%@\$*#&?!-]|[%@\$*#&?!-]\\{.*?\\}|[%@\$*#&?!-])"
    )
    private static final Pattern LENGTH_WITH_VARIANTS = Pattern.compile(
            "\\{((\\d+)-(\\d+)|(\\d+))\\}"
    )
    private static final Pattern LENGTH_WITH_STRING = Pattern.compile(
            "\\{'(.*)'(?:,(\\d+)-(\\d+))?(?:,(\\d+))?\\}"
    )

    private ParsePattern() {}

    private static TokenOptions parseLengthWithVariants(String part, List<String> variants) {
        Matcher match = LENGTH_WITH_VARIANTS.matcher(part)
        int startLength = 1
        int endLength = 1

        if (match.find()) {
            if (match.group(2) != null) {
                startLength = Integer.parseInt(match.group(2))
                endLength = Integer.parseInt(match.group(3))
            } else if (match.group(1) != null) {
                startLength = Integer.parseInt(match.group(1))
                endLength = startLength
            }
        }

        return TokenOptions.of(variants, startLength, endLength, part)
    }

    private static TokenOptions parseLengthWithString(String part) {
        Matcher match = LENGTH_WITH_STRING.matcher(part)
        if (!match.find()) {
            return null
        }

        if (match.group(2) != null && match.group(3) != null) {
            def options = new TokenOptions()
            options.string = match.group(1) != null ? match.group(1) : ""
            options.startLength = Integer.parseInt(match.group(2))
            options.endLength = Integer.parseInt(match.group(3))
            options.src = part
            return options
        }

        if (match.group(4) != null) {
            int length = Integer.parseInt(match.group(4))
            def options = new TokenOptions()
            options.string = match.group(1) != null ? match.group(1) : ""
            options.startLength = length
            options.endLength = length
            options.src = part
            return options
        }

        def options = new TokenOptions()
        options.string = match.group(1) != null ? match.group(1) : ""
        options.startLength = 1
        options.endLength = 1
        options.src = part
        return options
    }

    private static Function<String, Token> simpleTokenizer(String variantsString) {
        List<String> variants = new ArrayList<>()
        for (int i = 0; i < variantsString.length(); i++) {
            variants.add(String.valueOf(variantsString.charAt(i)))
        }
        return { String part -> new Token(parseLengthWithVariants(part, variants)) }
    }

    private static Token dictionaryTokenizer(String part, Map<String, List<String>> dictionaries) {
        TokenOptions options = parseLengthWithString(part)
        if (options == null
                || (options.string != null && !options.string.isEmpty() && !dictionaries.containsKey(options.string))) {
            return new Token(TokenOptions.of([part], 1, 1, part))
        }
        List<String> words = dictionaries.get(options.string != null ? options.string : "")
        options.variants = words != null ? words : []
        return new Token(options)
    }

    private static Token wordsTokenizer(String part) {
        TokenOptions options = parseLengthWithString(part)
        if (options == null) {
            return new Token(TokenOptions.of([part], 1, 1, part))
        }

        List<String> variants = new ArrayList<>()
        String workString = options.string != null ? options.string : ""
        int index = 0
        while (index < workString.length()) {
            if (index + 1 < workString.length()
                    && workString.charAt(index) == '\\'
                    && workString.charAt(index + 1) == ',') {
                index += 2
            } else if (workString.charAt(index) == ',') {
                variants.add(workString.substring(0, index))
                workString = workString.substring(index + 1)
                index = 0
            } else {
                index += 1
            }
        }
        variants.add(workString)
        List<String> cleaned = new ArrayList<>()
        for (String variant : variants) {
            cleaned.add(variant.replace("\\,", ","))
        }
        options.variants = cleaned
        return new Token(options)
    }

    private static Token partToToken(String part, Map<String, List<String>> dictionaries) {
        Map<Character, Function<String, Token>> tokenizers = new HashMap<>()
        tokenizers.put('#' as char, simpleTokenizer("0123456789"))
        tokenizers.put('@' as char, simpleTokenizer("abcdefghijklmnopqrstuvwxyz"))
        tokenizers.put('*' as char, simpleTokenizer("abcdefghijklmnopqrstuvwxyz0123456789"))
        tokenizers.put('-' as char, simpleTokenizer(
                "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"))
        tokenizers.put('!' as char, simpleTokenizer("ABCDEFGHIJKLMNOPQRSTUVWXYZ"))
        tokenizers.put('?' as char, simpleTokenizer("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"))
        tokenizers.put('&' as char, simpleTokenizer(
                "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"))
        tokenizers.put('%' as char, { String p -> dictionaryTokenizer(p, dictionaries) } as Function)
        tokenizers.put('$' as char, { String p -> wordsTokenizer(p) } as Function)

        Function<String, Token> tokenizer =
                part.isEmpty() ? null : tokenizers.get(part.charAt(0))
        boolean isEscapedToken = part.length() > 1
                && part.charAt(0) == '\\'
                && tokenizers.containsKey(part.charAt(1))

        if (tokenizer != null) {
            return tokenizer.apply(part)
        }
        if (isEscapedToken) {
            return new Token(TokenOptions.of([part.substring(1)], 1, 1, part))
        }
        return new Token(TokenOptions.of([part], 1, 1, part))
    }

    /** Split like JS/Python capturing-group split (Java's Pattern.split does not). */
    static List<String> splitKeepingDelimiters(String input) {
        List<String> parts = new ArrayList<>()
        Matcher matcher = TOKEN_PARSING_REGEX.matcher(input)
        int last = 0
        while (matcher.find()) {
            if (matcher.start() > last) {
                String before = input.substring(last, matcher.start())
                if (!before.isEmpty()) {
                    parts.add(before)
                }
            }
            String token = matcher.group(1)
            if (token != null && !token.isEmpty()) {
                parts.add(token)
            }
            last = matcher.end()
        }
        if (last < input.length()) {
            String rest = input.substring(last)
            if (!rest.isEmpty()) {
                parts.add(rest)
            }
        }
        return parts
    }

    static List<Token> parse(String inputPattern, Map<String, List<String>> dictionaries) {
        Map<String, List<String>> dicts = dictionaries != null ? dictionaries : [:]
        List<Token> tokens = new ArrayList<>()
        for (String part : splitKeepingDelimiters(inputPattern)) {
            tokens.add(partToToken(part, dicts))
        }
        return tokens
    }
}
