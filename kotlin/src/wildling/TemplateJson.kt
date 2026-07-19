package wildling

/**
 * Minimal JSON parser for wildling template files (stdlib only).
 * Supports objects, arrays, strings, numbers, booleans, and null.
 */
internal class TemplateJson private constructor(private val text: String) {
    private var pos: Int = 0

    companion object {
        fun parse(text: String): Any? {
            val parser = TemplateJson(text)
            val value = parser.parseValue()
            parser.skipWhitespace()
            if (parser.pos != parser.text.length) {
                throw IllegalArgumentException("Unexpected trailing JSON content")
            }
            return value
        }

        @Suppress("UNCHECKED_CAST")
        fun parseObject(text: String): Map<String, Any?> {
            val value = parse(text)
            if (value !is Map<*, *>) {
                throw IllegalArgumentException("Template root must be a JSON object")
            }
            return value as Map<String, Any?>
        }
    }

    private fun parseValue(): Any? {
        skipWhitespace()
        if (pos >= text.length) {
            throw IllegalArgumentException("Unexpected end of JSON")
        }
        val c = text[pos]
        return when {
            c == '{' -> parseObjectValue()
            c == '[' -> parseArray()
            c == '"' -> parseString()
            c == 't' || c == 'f' -> parseBoolean()
            c == 'n' -> parseNull()
            c == '-' || c in '0'..'9' -> parseNumber()
            else -> throw IllegalArgumentException("Unexpected character at $pos")
        }
    }

    private fun parseObjectValue(): Map<String, Any?> {
        expect('{')
        val obj = linkedMapOf<String, Any?>()
        skipWhitespace()
        if (peek('}')) {
            pos++
            return obj
        }
        while (true) {
            skipWhitespace()
            val key = parseString()
            skipWhitespace()
            expect(':')
            obj[key] = parseValue()
            skipWhitespace()
            if (peek('}')) {
                pos++
                return obj
            }
            expect(',')
        }
    }

    private fun parseArray(): List<Any?> {
        expect('[')
        val array = mutableListOf<Any?>()
        skipWhitespace()
        if (peek(']')) {
            pos++
            return array
        }
        while (true) {
            array.add(parseValue())
            skipWhitespace()
            if (peek(']')) {
                pos++
                return array
            }
            expect(',')
        }
    }

    private fun parseString(): String {
        expect('"')
        val out = StringBuilder()
        while (pos < text.length) {
            val c = text[pos++]
            when {
                c == '"' -> return out.toString()
                c == '\\' -> {
                    if (pos >= text.length) {
                        throw IllegalArgumentException("Unterminated escape")
                    }
                    when (val esc = text[pos++]) {
                        '"', '\\', '/' -> out.append(esc)
                        'b' -> out.append('\b')
                        'f' -> out.append('\u000c')
                        'n' -> out.append('\n')
                        'r' -> out.append('\r')
                        't' -> out.append('\t')
                        'u' -> {
                            if (pos + 4 > text.length) {
                                throw IllegalArgumentException("Invalid unicode escape")
                            }
                            val code = text.substring(pos, pos + 4).toInt(16)
                            out.append(code.toChar())
                            pos += 4
                        }
                        else -> throw IllegalArgumentException("Invalid escape \\$esc")
                    }
                }
                else -> out.append(c)
            }
        }
        throw IllegalArgumentException("Unterminated string")
    }

    private fun parseNumber(): Number {
        val start = pos
        if (peek('-')) {
            pos++
        }
        while (pos < text.length && text[pos].isDigit()) {
            pos++
        }
        var isDouble = false
        if (peek('.')) {
            isDouble = true
            pos++
            while (pos < text.length && text[pos].isDigit()) {
                pos++
            }
        }
        if (pos < text.length && (text[pos] == 'e' || text[pos] == 'E')) {
            isDouble = true
            pos++
            if (peek('+') || peek('-')) {
                pos++
            }
            while (pos < text.length && text[pos].isDigit()) {
                pos++
            }
        }
        val raw = text.substring(start, pos)
        return if (isDouble) raw.toDouble() else raw.toLong()
    }

    private fun parseBoolean(): Boolean {
        when {
            text.startsWith("true", pos) -> {
                pos += 4
                return true
            }
            text.startsWith("false", pos) -> {
                pos += 5
                return false
            }
            else -> throw IllegalArgumentException("Invalid boolean at $pos")
        }
    }

    private fun parseNull(): Any? {
        if (text.startsWith("null", pos)) {
            pos += 4
            return null
        }
        throw IllegalArgumentException("Invalid null at $pos")
    }

    private fun skipWhitespace() {
        while (pos < text.length) {
            when (text[pos]) {
                ' ', '\n', '\r', '\t' -> pos++
                else -> return
            }
        }
    }

    private fun peek(expected: Char): Boolean =
        pos < text.length && text[pos] == expected

    private fun expect(expected: Char) {
        skipWhitespace()
        if (!peek(expected)) {
            throw IllegalArgumentException("Expected '$expected' at $pos")
        }
        pos++
    }
}
