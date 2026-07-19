package wildling

class Generator(inputPattern: String, dictionaries: Dictionaries?) {
    val source: String = inputPattern
    private val tokens: List<Token> = ParsePattern.parse(inputPattern, dictionaries)
    private val count: Int

    init {
        var total = 1
        for (token in tokens) {
            total *= token.count()
        }
        count = total
    }

    fun count(): Int = count

    fun tokens(): List<Token> = tokens

    fun get(index: Int): String {
        if (index > count - 1 || index < 0) {
            return ""
        }
        val stringArray = mutableListOf<String>()
        var indexWithOffset = index
        for (token in tokens) {
            stringArray.add(token.get(indexWithOffset % token.count()))
            indexWithOffset /= token.count()
        }
        return stringArray.joinToString("")
    }
}
