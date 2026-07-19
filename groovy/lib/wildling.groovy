package wildling

/**
 * Library entry. Prefer {@link Wildling#create} / {@link Wildling#createWildling}.
 */
class WildlingLib {
    private WildlingLib() {}

    static Wildling createWildling(List patterns, Map dictionaries = null) {
        return Wildling.createWildling(patterns, dictionaries)
    }

    static Wildling create(List patterns, Map dictionaries = null) {
        return Wildling.create(patterns as List<String>, dictionaries as Map<String, List<String>>)
    }
}
