package wildling

class Wildling(
    patterns: List<String>?,
    dictionaries: Dictionaries? = null,
) {
    private val generators: List<Generator>
    private val patternCount: Int
    private var internalIndex: Int = 0

    init {
        val dicts = dictionaries ?: emptyMap()
        val gens = mutableListOf<Generator>()
        var total = 0
        if (patterns != null) {
            for (pattern in patterns) {
                val generator = Generator(pattern, dicts)
                gens.add(generator)
                total += generator.count()
            }
        }
        generators = gens
        patternCount = total
    }

    fun index(): Int = internalIndex

    fun count(): Int = patternCount

    fun reset() {
        internalIndex = 0
    }

    /** Next combination, or `false` when exhausted. */
    fun next(): Any {
        if (internalIndex == patternCount) {
            return false
        }
        internalIndex += 1
        return get(internalIndex - 1)
    }

    fun generators(): List<Generator> = generators

    /** Combination at index, or `false` if out of range. */
    fun get(index: Int): Any {
        if (index > patternCount - 1 || index < 0) {
            return false
        }
        var segmentIndex = 0
        for (generator in generators) {
            val patternIndex = index - segmentIndex
            if (patternIndex < generator.count()) {
                return generator.get(patternIndex)
            }
            segmentIndex += generator.count()
        }
        return false
    }

    companion object {
        const val VERSION: String = "2.0.0"

        fun create(
            patterns: List<String>,
            dictionaries: Dictionaries = emptyMap(),
        ): Wildling = Wildling(patterns, dictionaries)
    }
}
