import Foundation

struct TokenOptions {
    var string: String?
    var startLength: Int?
    var endLength: Int?
    var variants: [String]?
    var src: String?
}

final class Token {
    private let src: String
    private let startLength: Int
    private let endLength: Int
    private let variants: [String]
    private let countValue: Int

    init(_ options: TokenOptions) {
        self.src = options.src ?? ""
        self.startLength = Token.defaultInteger(options.startLength, 1)
        self.endLength = Token.defaultInteger(options.endLength, 1)
        self.variants = options.variants ?? []

        var total = 0
        if startLength <= endLength {
            for length in startLength...endLength {
                total += Token.pow(variants.count, length)
            }
        }
        self.countValue = total
    }

    func count() -> Int { countValue }

    func srcValue() -> String { src }

    func get(_ index: Int) -> String {
        if index > countValue - 1 || index < 0 {
            return ""
        }
        if index == 0 && startLength == 0 {
            return ""
        }

        var indexWithOffset = index
        var stringLength = startLength
        if startLength <= endLength {
            for length in startLength...endLength {
                stringLength = length
                let offsetCount = Token.pow(variants.count, length)
                if indexWithOffset < offsetCount {
                    break
                }
                indexWithOffset -= offsetCount
            }
        }

        var parts: [String] = []
        for _ in 0..<stringLength {
            let variantIndex = indexWithOffset % variants.count
            indexWithOffset /= variants.count
            parts.append(variants[variantIndex])
        }
        return parts.joined()
    }

    private static func defaultInteger(_ option: Int?, _ fallback: Int) -> Int {
        if let option, option >= 0 {
            return option
        }
        return fallback
    }

    private static func pow(_ base: Int, _ exp: Int) -> Int {
        var result = 1
        for _ in 0..<exp {
            result *= base
        }
        return result
    }
}
