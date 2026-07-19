package wildling

final class TokenOptions(
    var string: Option[String] = None,
    var startLength: Option[Int] = None,
    var endLength: Option[Int] = None,
    var variants: Option[Seq[String]] = None,
    var src: Option[String] = None
)

object TokenOptions {
  def of(
      variants: Seq[String],
      startLength: Int,
      endLength: Int,
      src: String
  ): TokenOptions =
    new TokenOptions(
      startLength = Some(startLength),
      endLength = Some(endLength),
      variants = Some(variants),
      src = Some(src)
    )
}

final class Token(options: TokenOptions) {
  private val src: String = options.src.getOrElse("")
  private val startLength: Int = Token.defaultInteger(options.startLength, 1)
  private val endLength: Int = Token.defaultInteger(options.endLength, 1)
  private val variants: Seq[String] = options.variants.getOrElse(Seq.empty)
  private val countValue: Int = {
    var total = 0
    var length = startLength
    while (length <= endLength) {
      total += Token.pow(variants.size, length)
      length += 1
    }
    total
  }

  def count(): Int = countValue

  def srcValue(): String = src

  def get(index: Int): String = {
    if (index > countValue - 1 || index < 0) return ""
    if (index == 0 && startLength == 0) return ""

    var indexWithOffset = index
    var stringLength = startLength
    var length = startLength
    var done = false
    while (length <= endLength && !done) {
      stringLength = length
      val offsetCount = Token.pow(variants.size, length)
      if (indexWithOffset < offsetCount) {
        done = true
      } else {
        indexWithOffset -= offsetCount
        length += 1
      }
    }

    val out = new StringBuilder
    var i = 0
    while (i < stringLength) {
      val variantIndex = indexWithOffset % variants.size
      indexWithOffset /= variants.size
      out.append(variants(variantIndex))
      i += 1
    }
    out.toString
  }
}

object Token {
  private def defaultInteger(option: Option[Int], fallback: Int): Int =
    option.filter(_ >= 0).getOrElse(fallback)

  private def pow(base: Int, exp: Int): Int = {
    var result = 1
    var i = 0
    while (i < exp) {
      result *= base
      i += 1
    }
    result
  }
}
