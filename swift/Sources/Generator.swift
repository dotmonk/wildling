final class Generator {
    let source: String
    private let tokens: [Token]
    private let countValue: Int

    init(_ inputPattern: String, dictionaries: Dictionaries?) {
        self.source = inputPattern
        self.tokens = ParsePattern.parse(inputPattern, dictionaries: dictionaries)
        var total = 1
        for token in tokens {
            total *= token.count()
        }
        self.countValue = total
    }

    func count() -> Int { countValue }

    func get(_ index: Int) -> String {
        if index > countValue - 1 || index < 0 {
            return ""
        }
        var parts: [String] = []
        var indexWithOffset = index
        for token in tokens {
            parts.append(token.get(indexWithOffset % token.count()))
            indexWithOffset /= token.count()
        }
        return parts.joined()
    }
}
