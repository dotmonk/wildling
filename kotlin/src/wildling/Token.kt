package wildling

data class TokenOptions(
    var string: String? = null,
    var startLength: Int? = null,
    var endLength: Int? = null,
    var variants: List<String>? = null,
    var src: String? = null,
)

class Token(options: TokenOptions) {
    private val src: String = options.src ?: ""
    private val startLength: Int = defaultInteger(options.startLength, 1)
    private val endLength: Int = defaultInteger(options.endLength, 1)
    private val variants: List<String> = options.variants?.toList() ?: emptyList()
    private val count: Int

    init {
        var total = 0
        for (length in startLength..endLength) {
            total += pow(variants.size, length)
        }
        count = total
    }

    fun count(): Int = count

    fun src(): String = src

    fun get(index: Int): String {
        if (index > count - 1 || index < 0) {
            return ""
        }
        if (index == 0 && startLength == 0) {
            return ""
        }

        var indexWithOffset = index
        var stringLength = startLength
        for (length in startLength..endLength) {
            stringLength = length
            val offsetCount = pow(variants.size, length)
            if (indexWithOffset < offsetCount) {
                break
            }
            indexWithOffset -= offsetCount
        }

        val out = StringBuilder()
        repeat(stringLength) {
            val variantIndex = indexWithOffset % variants.size
            indexWithOffset /= variants.size
            out.append(variants[variantIndex])
        }
        return out.toString()
    }

    companion object {
        private fun defaultInteger(option: Int?, fallback: Int): Int =
            if (option != null && option >= 0) option else fallback

        private fun pow(base: Int, exp: Int): Int {
            var result = 1
            repeat(exp) { result *= base }
            return result
        }
    }
}
