public final class Wildling {
    public static let version = "2.0.5"

    private let generators: [Generator]
    private let patternCount: Int
    private var internalIndex: Int = 0

    public init(patterns: [String], dictionaries: Dictionaries? = nil) {
        let dicts = dictionaries ?? [:]
        var gens: [Generator] = []
        var total = 0
        for pattern in patterns {
            let generator = Generator(pattern, dictionaries: dicts)
            gens.append(generator)
            total += generator.count()
        }
        self.generators = gens
        self.patternCount = total
    }

    public func index() -> Int { internalIndex }

    public func count() -> Int { patternCount }

    public func reset() {
        internalIndex = 0
    }

    /// Next combination, or `nil` when exhausted.
    public func next() -> String? {
        if internalIndex == patternCount {
            return nil
        }
        internalIndex += 1
        return get(internalIndex - 1)
    }

    func generatorsList() -> [Generator] { generators }

    /// Combination at index, or `nil` if out of range.
    public func get(_ index: Int) -> String? {
        if index > patternCount - 1 || index < 0 {
            return nil
        }
        var segmentIndex = 0
        for generator in generators {
            let patternIndex = index - segmentIndex
            if patternIndex < generator.count() {
                return generator.get(patternIndex)
            }
            segmentIndex += generator.count()
        }
        return nil
    }
}
