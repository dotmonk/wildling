package wildling

object Wildling {
  val Version: String = "2.0.3"

  def apply(
      patterns: Seq[String],
      dictionaries: ParsePattern.Dictionaries = Map.empty
  ): Wildling =
    new Wildling(patterns, dictionaries)
}

final class Wildling(
    patterns: Seq[String],
    dictionaries: ParsePattern.Dictionaries = Map.empty
) {
  private val gens: Seq[Generator] =
    patterns.map(pattern => new Generator(pattern, dictionaries))
  private val patternCount: Int = gens.map(_.count()).sum
  private var internalIndex: Int = 0

  def index(): Int = internalIndex

  def count(): Int = patternCount

  def reset(): Unit = {
    internalIndex = 0
  }

  /** Next combination, or `false` when exhausted. */
  def next(): Any = {
    if (internalIndex == patternCount) return false
    internalIndex += 1
    get(internalIndex - 1)
  }

  def generators(): Seq[Generator] = gens

  /** Combination at index, or `false` if out of range. */
  def get(index: Int): Any = {
    if (index > patternCount - 1 || index < 0) return false
    var segmentIndex = 0
    gens.foreach { generator =>
      val patternIndex = index - segmentIndex
      if (patternIndex < generator.count()) {
        return generator.get(patternIndex)
      }
      segmentIndex += generator.count()
    }
    false
  }
}
