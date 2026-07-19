package wildling

final class Generator(inputPattern: String, dictionaries: ParsePattern.Dictionaries) {
  val source: String = inputPattern
  private val tokens: Seq[Token] = ParsePattern.parse(inputPattern, dictionaries)
  private val countValue: Int = {
    var total = 1
    tokens.foreach(token => total *= token.count())
    total
  }

  def count(): Int = countValue

  def get(index: Int): String = {
    if (index > countValue - 1 || index < 0) return ""
    val out = new StringBuilder
    var indexWithOffset = index
    tokens.foreach { token =>
      out.append(token.get(indexWithOffset % token.count()))
      indexWithOffset /= token.count()
    }
    out.toString
  }
}
