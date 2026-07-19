package wildling

import java.util.regex.Pattern
import scala.collection.mutable
import scala.collection.mutable.ArrayBuffer

object ParsePattern {
  type Dictionaries = Map[String, Seq[String]]

  private val TokenParsingRegex: Pattern = Pattern.compile(
    "(\\\\[%@$*#&?!-]|[%@$*#&?!-]\\{.*?\\}|[%@$*#&?!-])"
  )
  private val LengthWithVariants: Pattern = Pattern.compile(
    "\\{((\\d+)-(\\d+)|(\\d+))\\}"
  )
  private val LengthWithString: Pattern = Pattern.compile(
    "\\{'(.*)'(?:,(\\d+)-(\\d+))?(?:,(\\d+))?\\}"
  )

  private def parseLengthWithVariants(part: String, variants: Seq[String]): TokenOptions = {
    val matchResult = LengthWithVariants.matcher(part)
    var startLength = 1
    var endLength = 1

    if (matchResult.find()) {
      if (matchResult.group(2) != null) {
        startLength = matchResult.group(2).toInt
        endLength = matchResult.group(3).toInt
      } else if (matchResult.group(1) != null) {
        startLength = matchResult.group(1).toInt
        endLength = startLength
      }
    }

    TokenOptions.of(variants, startLength, endLength, part)
  }

  private def parseLengthWithString(part: String): Option[TokenOptions] = {
    val matchResult = LengthWithString.matcher(part)
    if (!matchResult.find()) return None

    val string = Option(matchResult.group(1)).getOrElse("")
    if (matchResult.group(2) != null && matchResult.group(3) != null) {
      return Some(
        new TokenOptions(
          string = Some(string),
          startLength = Some(matchResult.group(2).toInt),
          endLength = Some(matchResult.group(3).toInt),
          src = Some(part)
        )
      )
    }

    if (matchResult.group(4) != null) {
      val length = matchResult.group(4).toInt
      return Some(
        new TokenOptions(
          string = Some(string),
          startLength = Some(length),
          endLength = Some(length),
          src = Some(part)
        )
      )
    }

    Some(
      new TokenOptions(
        string = Some(string),
        startLength = Some(1),
        endLength = Some(1),
        src = Some(part)
      )
    )
  }

  private def simpleTokenizer(variantsString: String): String => Token = {
    val variants = variantsString.map(_.toString)
    (part: String) => new Token(parseLengthWithVariants(part, variants))
  }

  private def dictionaryTokenizer(part: String, dictionaries: Dictionaries): Token = {
    var options = parseLengthWithString(part)
    val key = options.flatMap(_.string)
    if (
      options.isEmpty ||
      key.exists(k => k.nonEmpty && !dictionaries.contains(k))
    ) {
      options = Some(TokenOptions.of(Seq(part), 1, 1, part))
    } else {
      val opts = options.get
      opts.variants = Some(dictionaries.getOrElse(key.getOrElse(""), Seq.empty))
    }
    new Token(options.get)
  }

  private def wordsTokenizer(part: String): Token = {
    var options = parseLengthWithString(part)
    if (options.isEmpty) {
      options = Some(TokenOptions.of(Seq(part), 1, 1, part))
    } else {
      val opts = options.get
      val variants = ArrayBuffer.empty[String]
      var workString = opts.string.getOrElse("")
      var index = 0
      while (index < workString.length) {
        if (
          index + 1 < workString.length &&
          workString.charAt(index) == '\\' &&
          workString.charAt(index + 1) == ','
        ) {
          index += 2
        } else if (workString.charAt(index) == ',') {
          variants += workString.substring(0, index)
          workString = workString.substring(index + 1)
          index = 0
        } else {
          index += 1
        }
      }
      variants += workString
      opts.variants = Some(variants.map(_.replace("\\,", ",")).toSeq)
    }
    new Token(options.get)
  }

  private def partToToken(part: String, dictionaries: Dictionaries): Token = {
    val tokenizers = mutable.Map[Char, String => Token](
      '#' -> simpleTokenizer("0123456789"),
      '@' -> simpleTokenizer("abcdefghijklmnopqrstuvwxyz"),
      '*' -> simpleTokenizer("abcdefghijklmnopqrstuvwxyz0123456789"),
      '-' -> simpleTokenizer(
        "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
      ),
      '!' -> simpleTokenizer("ABCDEFGHIJKLMNOPQRSTUVWXYZ"),
      '?' -> simpleTokenizer("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"),
      '&' -> simpleTokenizer("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"),
      '%' -> ((p: String) => dictionaryTokenizer(p, dictionaries)),
      '$' -> ((p: String) => wordsTokenizer(p))
    )

    val tokenizer = if (part.nonEmpty) tokenizers.get(part.charAt(0)) else None
    val isEscaped =
      part.length > 1 && part.charAt(0) == '\\' && tokenizers.contains(part.charAt(1))

    if (tokenizer.isDefined) {
      tokenizer.get(part)
    } else if (isEscaped) {
      new Token(TokenOptions.of(Seq(part.substring(1)), 1, 1, part))
    } else {
      new Token(TokenOptions.of(Seq(part), 1, 1, part))
    }
  }

  /** Split like JS/Python capturing-group split. */
  private def splitKeepingDelimiters(input: String): Seq[String] = {
    val parts = ArrayBuffer.empty[String]
    val matcher = TokenParsingRegex.matcher(input)
    var last = 0
    while (matcher.find()) {
      if (matcher.start() > last) {
        val before = input.substring(last, matcher.start())
        if (before.nonEmpty) parts += before
      }
      val token = matcher.group(1)
      if (token != null && token.nonEmpty) parts += token
      last = matcher.end()
    }
    if (last < input.length) {
      val rest = input.substring(last)
      if (rest.nonEmpty) parts += rest
    }
    parts.toSeq
  }

  def parse(inputPattern: String, dictionaries: Dictionaries): Seq[Token] = {
    val dicts = if (dictionaries == null) Map.empty[String, Seq[String]] else dictionaries
    splitKeepingDelimiters(inputPattern).map(partToToken(_, dicts))
  }
}
