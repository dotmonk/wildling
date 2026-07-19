import Foundation

typealias Dictionaries = [String: [String]]

enum ParsePattern {
    private static let tokenParsingPattern =
        "(\\\\[%@$*#&?!-]|[%@$*#&?!-]\\{.*?\\}|[%@$*#&?!-])"
    private static let lengthWithVariantsPattern = "\\{((\\d+)-(\\d+)|(\\d+))\\}"
    private static let lengthWithStringPattern =
        "\\{'(.*)'(?:,(\\d+)-(\\d+))?(?:,(\\d+))?\\}"

    private static func parseLengthWithVariants(_ part: String, variants: [String]) -> TokenOptions {
        var startLength = 1
        var endLength = 1

        if let regex = try? NSRegularExpression(pattern: lengthWithVariantsPattern),
           let match = firstMatch(regex, in: part) {
            let g2 = group(match, 2, in: part)
            let g3 = group(match, 3, in: part)
            let g1 = group(match, 1, in: part)
            if let g2, let g3, let s = Int(g2), let e = Int(g3) {
                startLength = s
                endLength = e
            } else if let g1, let s = Int(g1) {
                startLength = s
                endLength = startLength
            }
        }

        return TokenOptions(
            startLength: startLength,
            endLength: endLength,
            variants: variants,
            src: part
        )
    }

    private static func parseLengthWithString(_ part: String) -> TokenOptions? {
        guard let regex = try? NSRegularExpression(pattern: lengthWithStringPattern),
              let match = firstMatch(regex, in: part) else {
            return nil
        }

        let string = group(match, 1, in: part) ?? ""
        let g2 = group(match, 2, in: part)
        let g3 = group(match, 3, in: part)
        let g4 = group(match, 4, in: part)

        if let g2, let g3, let s = Int(g2), let e = Int(g3) {
            return TokenOptions(
                string: string,
                startLength: s,
                endLength: e,
                src: part
            )
        }

        if let g4, let length = Int(g4) {
            return TokenOptions(
                string: string,
                startLength: length,
                endLength: length,
                src: part
            )
        }

        return TokenOptions(
            string: string,
            startLength: 1,
            endLength: 1,
            src: part
        )
    }

    private static func simpleTokenizer(_ variantsString: String) -> (String) -> Token {
        let variants = variantsString.map { String($0) }
        return { part in Token(parseLengthWithVariants(part, variants: variants)) }
    }

    private static func dictionaryTokenizer(_ part: String, dictionaries: Dictionaries) -> Token {
        var options = parseLengthWithString(part)
        let key = options?.string
        if options == nil || (key != nil && !(key!.isEmpty) && dictionaries[key!] == nil) {
            options = TokenOptions(
                startLength: 1,
                endLength: 1,
                variants: [part],
                src: part
            )
        } else {
            options?.variants = dictionaries[key ?? ""] ?? []
        }
        return Token(options!)
    }

    private static func wordsTokenizer(_ part: String) -> Token {
        var options = parseLengthWithString(part)
        if options == nil {
            options = TokenOptions(
                startLength: 1,
                endLength: 1,
                variants: [part],
                src: part
            )
        } else {
            var variants: [String] = []
            var workString = options?.string ?? ""
            var index = workString.startIndex
            while index < workString.endIndex {
                let next = workString.index(after: index)
                if next < workString.endIndex,
                   workString[index] == "\\",
                   workString[next] == "," {
                    index = workString.index(after: next)
                } else if workString[index] == "," {
                    variants.append(String(workString[..<index]))
                    workString = String(workString[workString.index(after: index)...])
                    index = workString.startIndex
                } else {
                    index = next
                }
            }
            variants.append(workString)
            options?.variants = variants.map { $0.replacingOccurrences(of: "\\,", with: ",") }
        }
        return Token(options!)
    }

    private static func partToToken(_ part: String, dictionaries: Dictionaries) -> Token {
        let tokenizers: [Character: (String) -> Token] = [
            "#": simpleTokenizer("0123456789"),
            "@": simpleTokenizer("abcdefghijklmnopqrstuvwxyz"),
            "*": simpleTokenizer("abcdefghijklmnopqrstuvwxyz0123456789"),
            "-": simpleTokenizer(
                "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
            ),
            "!": simpleTokenizer("ABCDEFGHIJKLMNOPQRSTUVWXYZ"),
            "?": simpleTokenizer("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"),
            "&": simpleTokenizer("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"),
            "%": { dictionaryTokenizer($0, dictionaries: dictionaries) },
            "$": wordsTokenizer,
        ]

        let first = part.first
        let tokenizer = first.flatMap { tokenizers[$0] }
        let isEscaped =
            part.count > 1 && part.first == "\\" && tokenizers[part[part.index(after: part.startIndex)]] != nil

        if let tokenizer {
            return tokenizer(part)
        }
        if isEscaped {
            var stripped = part
            if stripped.hasPrefix("\\") {
                stripped.removeFirst()
            }
            return Token(TokenOptions(variants: [stripped], src: part))
        }
        return Token(TokenOptions(variants: [part], src: part))
    }

    /// Split like JS/Python capturing-group split.
    private static func splitKeepingDelimiters(_ input: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: tokenParsingPattern) else {
            return input.isEmpty ? [] : [input]
        }
        let ns = input as NSString
        let full = NSRange(location: 0, length: ns.length)
        let matches = regex.matches(in: input, options: [], range: full)
        if matches.isEmpty {
            return input.isEmpty ? [] : [input]
        }

        var parts: [String] = []
        var last = 0
        for match in matches {
            if match.range.location > last {
                let before = ns.substring(
                    with: NSRange(location: last, length: match.range.location - last)
                )
                if !before.isEmpty {
                    parts.append(before)
                }
            }
            let g1 = match.range(at: 1)
            if g1.location != NSNotFound && g1.length > 0 {
                parts.append(ns.substring(with: g1))
            }
            last = match.range.location + match.range.length
        }
        if last < ns.length {
            let rest = ns.substring(with: NSRange(location: last, length: ns.length - last))
            if !rest.isEmpty {
                parts.append(rest)
            }
        }
        return parts
    }

    static func parse(_ inputPattern: String, dictionaries: Dictionaries?) -> [Token] {
        let dicts = dictionaries ?? [:]
        return splitKeepingDelimiters(inputPattern).map { partToToken($0, dictionaries: dicts) }
    }

    private static func firstMatch(_ regex: NSRegularExpression, in text: String) -> NSTextCheckingResult? {
        let ns = text as NSString
        return regex.firstMatch(
            in: text,
            options: [],
            range: NSRange(location: 0, length: ns.length)
        )
    }

    private static func group(_ match: NSTextCheckingResult, _ index: Int, in text: String) -> String? {
        let range = match.range(at: index)
        guard range.location != NSNotFound else { return nil }
        return (text as NSString).substring(with: range)
    }
}
