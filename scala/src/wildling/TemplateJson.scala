package wildling

import scala.collection.mutable
import scala.collection.mutable.ArrayBuffer

/** Minimal JSON parser for wildling template files (stdlib only). */
private[wildling] object TemplateJson {
  def parse(text: String): Any = {
    val parser = new Parser(text)
    val value = parser.parseValue()
    parser.skipWhitespace()
    if (parser.pos != text.length) {
      throw new IllegalArgumentException("Unexpected trailing JSON content")
    }
    value
  }

  def parseObject(text: String): mutable.LinkedHashMap[String, Any] = {
    parse(text) match {
      case m: mutable.LinkedHashMap[_, _] =>
        m.asInstanceOf[mutable.LinkedHashMap[String, Any]]
      case _ =>
        throw new IllegalArgumentException("Template root must be a JSON object")
    }
  }

  private final class Parser(text: String) {
    var pos: Int = 0

    def parseValue(): Any = {
      skipWhitespace()
      if (pos >= text.length) {
        throw new IllegalArgumentException("Unexpected end of JSON")
      }
      text.charAt(pos) match {
        case '{' => parseObjectValue()
        case '[' => parseArray()
        case '"' => parseString()
        case 't' | 'f' => parseBoolean()
        case 'n' => parseNull()
        case c if c == '-' || c.isDigit => parseNumber()
        case _ => throw new IllegalArgumentException(s"Unexpected character at $pos")
      }
    }

    private def parseObjectValue(): mutable.LinkedHashMap[String, Any] = {
      expect('{')
      val obj = mutable.LinkedHashMap.empty[String, Any]
      skipWhitespace()
      if (peek('}')) {
        pos += 1
        return obj
      }
      while (true) {
        skipWhitespace()
        val key = parseString()
        skipWhitespace()
        expect(':')
        obj(key) = parseValue()
        skipWhitespace()
        if (peek('}')) {
          pos += 1
          return obj
        }
        expect(',')
      }
      obj
    }

    private def parseArray(): Seq[Any] = {
      expect('[')
      val array = ArrayBuffer.empty[Any]
      skipWhitespace()
      if (peek(']')) {
        pos += 1
        return array.toSeq
      }
      while (true) {
        array += parseValue()
        skipWhitespace()
        if (peek(']')) {
          pos += 1
          return array.toSeq
        }
        expect(',')
      }
      array.toSeq
    }

    private def parseString(): String = {
      expect('"')
      val out = new StringBuilder
      while (pos < text.length) {
        val c = text.charAt(pos)
        pos += 1
        if (c == '"') return out.toString
        if (c == '\\') {
          if (pos >= text.length) {
            throw new IllegalArgumentException("Unterminated escape")
          }
          val esc = text.charAt(pos)
          pos += 1
          esc match {
            case '"' | '\\' | '/' => out.append(esc)
            case 'b' => out.append('\b')
            case 'f' => out.append('\f')
            case 'n' => out.append('\n')
            case 'r' => out.append('\r')
            case 't' => out.append('\t')
            case 'u' =>
              if (pos + 4 > text.length) {
                throw new IllegalArgumentException("Invalid unicode escape")
              }
              val code = Integer.parseInt(text.substring(pos, pos + 4), 16)
              out.append(code.toChar)
              pos += 4
            case _ => throw new IllegalArgumentException(s"Invalid escape \\$esc")
          }
        } else {
          out.append(c)
        }
      }
      throw new IllegalArgumentException("Unterminated string")
    }

    private def parseNumber(): Any = {
      val start = pos
      if (peek('-')) pos += 1
      while (pos < text.length && text.charAt(pos).isDigit) pos += 1
      var isDouble = false
      if (peek('.')) {
        isDouble = true
        pos += 1
        while (pos < text.length && text.charAt(pos).isDigit) pos += 1
      }
      if (pos < text.length && (text.charAt(pos) == 'e' || text.charAt(pos) == 'E')) {
        isDouble = true
        pos += 1
        if (peek('+') || peek('-')) pos += 1
        while (pos < text.length && text.charAt(pos).isDigit) pos += 1
      }
      val raw = text.substring(start, pos)
      if (isDouble) raw.toDouble else raw.toLong
    }

    private def parseBoolean(): Boolean = {
      if (text.startsWith("true", pos)) {
        pos += 4
        true
      } else if (text.startsWith("false", pos)) {
        pos += 5
        false
      } else {
        throw new IllegalArgumentException(s"Invalid boolean at $pos")
      }
    }

    private def parseNull(): Null = {
      if (text.startsWith("null", pos)) {
        pos += 4
        null
      } else {
        throw new IllegalArgumentException(s"Invalid null at $pos")
      }
    }

    def skipWhitespace(): Unit = {
      while (pos < text.length) {
        text.charAt(pos) match {
          case ' ' | '\n' | '\r' | '\t' => pos += 1
          case _ => return
        }
      }
    }

    private def peek(expected: Char): Boolean =
      pos < text.length && text.charAt(pos) == expected

    private def expect(expected: Char): Unit = {
      skipWhitespace()
      if (!peek(expected)) {
        throw new IllegalArgumentException(s"Expected '$expected' at $pos")
      }
      pos += 1
    }
  }
}
