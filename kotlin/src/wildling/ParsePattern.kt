package wildling

import java.util.regex.Pattern

typealias Dictionaries = Map<String, List<String>>

internal object ParsePattern {
    private val TOKEN_PARSING_REGEX: Pattern = Pattern.compile(
        "(\\\\[%@$*#&?!-]|[%@$*#&?!-]\\{.*?\\}|[%@$*#&?!-])"
    )
    private val LENGTH_WITH_VARIANTS: Pattern = Pattern.compile(
        "\\{((\\d+)-(\\d+)|(\\d+))\\}"
    )
    private val LENGTH_WITH_STRING: Pattern = Pattern.compile(
        "\\{'(.*)'(?:,(\\d+)-(\\d+))?(?:,(\\d+))?\\}"
    )

    private fun parseLengthWithVariants(part: String, variants: List<String>): TokenOptions {
        val match = LENGTH_WITH_VARIANTS.matcher(part)
        var startLength = 1
        var endLength = 1

        if (match.find()) {
            if (match.group(2) != null) {
                startLength = match.group(2).toInt()
                endLength = match.group(3).toInt()
            } else if (match.group(1) != null) {
                startLength = match.group(1).toInt()
                endLength = startLength
            }
        }

        return TokenOptions(
            variants = variants,
            startLength = startLength,
            endLength = endLength,
            src = part,
        )
    }

    private fun parseLengthWithString(part: String): TokenOptions? {
        val match = LENGTH_WITH_STRING.matcher(part)
        if (!match.find()) {
            return null
        }

        val string = match.group(1) ?: ""
        if (match.group(2) != null && match.group(3) != null) {
            return TokenOptions(
                string = string,
                startLength = match.group(2).toInt(),
                endLength = match.group(3).toInt(),
                src = part,
            )
        }

        if (match.group(4) != null) {
            val length = match.group(4).toInt()
            return TokenOptions(
                string = string,
                startLength = length,
                endLength = length,
                src = part,
            )
        }

        return TokenOptions(
            string = string,
            startLength = 1,
            endLength = 1,
            src = part,
        )
    }

    private fun simpleTokenizer(variantsString: String): (String) -> Token {
        val variants = variantsString.map { it.toString() }
        return { part -> Token(parseLengthWithVariants(part, variants)) }
    }

    private fun dictionaryTokenizer(part: String, dictionaries: Dictionaries): Token {
        var options = parseLengthWithString(part)
        val key = options?.string
        if (options == null || (key != null && key.isNotEmpty() && key !in dictionaries)) {
            options = TokenOptions(
                variants = listOf(part),
                startLength = 1,
                endLength = 1,
                src = part,
            )
        } else {
            options.variants = dictionaries[key ?: ""] ?: emptyList()
        }
        return Token(options)
    }

    private fun wordsTokenizer(part: String): Token {
        var options = parseLengthWithString(part)
        if (options == null) {
            options = TokenOptions(
                variants = listOf(part),
                startLength = 1,
                endLength = 1,
                src = part,
            )
        } else {
            val variants = mutableListOf<String>()
            var workString = options.string ?: ""
            var index = 0
            while (index < workString.length) {
                if (index + 1 < workString.length &&
                    workString[index] == '\\' &&
                    workString[index + 1] == ','
                ) {
                    index += 2
                } else if (workString[index] == ',') {
                    variants.add(workString.substring(0, index))
                    workString = workString.substring(index + 1)
                    index = 0
                } else {
                    index += 1
                }
            }
            variants.add(workString)
            options.variants = variants.map { it.replace("\\,", ",") }
        }
        return Token(options)
    }

    private fun partToToken(part: String, dictionaries: Dictionaries): Token {
        val tokenizers = mapOf(
            '#' to simpleTokenizer("0123456789"),
            '@' to simpleTokenizer("abcdefghijklmnopqrstuvwxyz"),
            '*' to simpleTokenizer("abcdefghijklmnopqrstuvwxyz0123456789"),
            '-' to simpleTokenizer(
                "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
            ),
            '!' to simpleTokenizer("ABCDEFGHIJKLMNOPQRSTUVWXYZ"),
            '?' to simpleTokenizer("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"),
            '&' to simpleTokenizer(
                "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
            ),
            '%' to { p: String -> dictionaryTokenizer(p, dictionaries) },
            '$' to { p: String -> wordsTokenizer(p) },
        )

        val tokenizer = if (part.isNotEmpty()) tokenizers[part[0]] else null
        val isEscaped =
            part.length > 1 && part[0] == '\\' && tokenizers.containsKey(part[1])

        return when {
            tokenizer != null -> tokenizer(part)
            isEscaped -> Token(
                TokenOptions(
                    variants = listOf(part.substring(1)),
                    startLength = 1,
                    endLength = 1,
                    src = part,
                )
            )
            else -> Token(
                TokenOptions(
                    variants = listOf(part),
                    startLength = 1,
                    endLength = 1,
                    src = part,
                )
            )
        }
    }

    /** Split like JS/Python capturing-group split (Java Pattern.split does not). */
    private fun splitKeepingDelimiters(input: String): List<String> {
        val parts = mutableListOf<String>()
        val matcher = TOKEN_PARSING_REGEX.matcher(input)
        var last = 0
        while (matcher.find()) {
            if (matcher.start() > last) {
                val before = input.substring(last, matcher.start())
                if (before.isNotEmpty()) {
                    parts.add(before)
                }
            }
            val token = matcher.group(1)
            if (!token.isNullOrEmpty()) {
                parts.add(token)
            }
            last = matcher.end()
        }
        if (last < input.length) {
            val rest = input.substring(last)
            if (rest.isNotEmpty()) {
                parts.add(rest)
            }
        }
        return parts
    }

    fun parse(inputPattern: String, dictionaries: Dictionaries?): List<Token> {
        val dicts = dictionaries ?: emptyMap()
        return splitKeepingDelimiters(inputPattern).map { partToToken(it, dicts) }
    }
}
