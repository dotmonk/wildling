import Foundation

struct CliRange {
    let start: Int
    let end: Int
}

final class CliArgs {
    var selects: [Int] = []
    var ranges: [CliRange] = []
    var check: Bool = false
    var dictionaries: Dictionaries = [:]
    var dictionaryOrder: [String] = []
    var patterns: [String] = []
    var help: Bool = false
    var version: Bool = false

    func setDictionary(_ name: String, _ words: [String]) {
        if dictionaries[name] == nil {
            dictionaryOrder.append(name)
        }
        dictionaries[name] = words
    }
}

enum Cli {
    static func parseRange(_ value: String) -> CliRange? {
        let parts = value.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2 else { return nil }
        let startStr = String(parts[0])
        let endStr = String(parts[1])
        guard startStr.allSatisfy(\.isNumber), endStr.allSatisfy(\.isNumber),
              let start = Int(startStr), let end = Int(endStr), start <= end else {
            return nil
        }
        return CliRange(start: start, end: end)
    }

    static func loadDictionaryFile(_ path: String) throws -> [String] {
        let content = try String(contentsOfFile: path, encoding: .utf8)
        return content
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    static func applyDictionary(_ result: CliArgs, name: String, value: Any) {
        if let list = value as? [Any] {
            result.setDictionary(name, list.map { String(describing: $0) })
            return
        }
        if let list = value as? [String] {
            result.setDictionary(name, list)
            return
        }
        if let path = value as? String {
            if FileManager.default.fileExists(atPath: path) {
                if let words = try? loadDictionaryFile(path) {
                    result.setDictionary(name, words)
                }
            }
        }
    }

    static func applyTemplate(_ result: CliArgs, path: String) {
        guard FileManager.default.fileExists(atPath: path) else {
            fputs("Template file not found: \(path)\n", stderr)
            exit(1)
        }

        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let json = try? JSONSerialization.jsonObject(with: data),
              let template = json as? [String: Any] else {
            fputs("Invalid JSON template: \(path)\n", stderr)
            exit(1)
        }

        if let check = template["check"] as? Bool, check {
            result.check = true
        }

        if let select = template["select"] as? [Any] {
            for val in select {
                if let number = intValue(val), number >= 0 {
                    result.selects.append(number)
                }
            }
        }

        if let ranges = template["range"] as? [Any] {
            for rangeVal in ranges {
                if let parsed = parseRange(String(describing: rangeVal)) {
                    result.ranges.append(parsed)
                }
            }
        }

        if let dictionaries = template["dictionaries"] as? [String: Any] {
            for (name, value) in dictionaries {
                applyDictionary(result, name: name, value: value)
            }
        }

        if let patterns = template["patterns"] as? [Any] {
            for pattern in patterns {
                result.patterns.append(String(describing: pattern))
            }
        }
    }

    static func parseArgs(_ args: [String]) -> CliArgs {
        let result = CliArgs()
        var i = 0
        while i < args.count {
            let arg = args[i]
            switch arg {
            case "--help", "-h":
                result.help = true
                i += 1
            case "--version", "-v":
                result.version = true
                i += 1
            case "--check":
                result.check = true
                i += 1
            case "--select":
                i += 1
                if i >= args.count { break }
                if let val = Int(args[i]), val >= 0 {
                    result.selects.append(val)
                }
                i += 1
            case "--range":
                i += 1
                if i >= args.count { break }
                if let parsed = parseRange(args[i]) {
                    result.ranges.append(parsed)
                }
                i += 1
            case "--dictionary":
                i += 1
                if i >= args.count { break }
                let spec = args[i]
                if let colon = spec.firstIndex(of: ":") {
                    let name = String(spec[..<colon])
                    let path = String(spec[spec.index(after: colon)...])
                    if !name.isEmpty && !path.isEmpty {
                        applyDictionary(result, name: name, value: path)
                    }
                }
                i += 1
            case "--template":
                i += 1
                if i >= args.count {
                    fputs("Missing path for --template\n", stderr)
                    exit(1)
                }
                applyTemplate(result, path: args[i])
                i += 1
            default:
                result.patterns.append(arg)
                i += 1
            }
        }
        return result
    }

    static func loadHelpText() -> String {
        var candidates: [String] = []
        let exe = CommandLine.arguments[0]
        let exeDir = URL(fileURLWithPath: exe).deletingLastPathComponent().path
        candidates.append((exeDir as NSString).appendingPathComponent("help.txt"))
        candidates.append(
            ((exeDir as NSString).appendingPathComponent("..") as NSString)
                .appendingPathComponent("docs/help.txt")
        )
        candidates.append("docs/help.txt")

        for path in candidates {
            if let content = try? String(contentsOfFile: path, encoding: .utf8) {
                return content
            }
        }
        return "wildling - pattern based string generator\n\nHelp text unavailable.\n"
    }

    static func formatList(_ values: [String]) -> String {
        values.isEmpty ? "" : " " + values.joined(separator: " ")
    }

    static func formatCheckOutput(_ args: CliArgs, total: Int, generators: [Generator]) -> String {
        let rangeStrings = args.ranges.map { "\($0.start)-\($0.end)" }
        var lines = [
            "patterns:\(formatList(args.patterns))",
            "dictionaries:\(formatList(args.dictionaryOrder))",
            "select:\(formatList(args.selects.map(String.init)))",
            "range:\(formatList(rangeStrings))",
            "total: \(total)",
        ]
        for gen in generators {
            lines.append("generator: \(gen.source) \(gen.count())")
        }
        return lines.joined(separator: "\n")
    }

    static func run(argv: [String]) -> Int32 {
        let args = parseArgs(argv)

        if args.help {
            print(loadHelpText().rstrip())
            return 0
        }

        if args.version {
            print("wildling \(Wildling.version)")
            return 0
        }

        if args.patterns.isEmpty {
            fputs("No pattern provided. Use --help for usage information.\n", stderr)
            return 1
        }

        let wildcard = Wildling(patterns: args.patterns, dictionaries: args.dictionaries)

        if args.check {
            print(formatCheckOutput(args, total: wildcard.count(), generators: wildcard.generatorsList()))
            return 0
        }

        if !args.selects.isEmpty || !args.ranges.isEmpty {
            for index in args.selects {
                if let value = wildcard.get(index) {
                    print(value)
                } else {
                    print("false")
                }
            }
            for range in args.ranges {
                for index in range.start...range.end {
                    if let value = wildcard.get(index) {
                        print(value)
                    } else {
                        print("false")
                    }
                }
            }
            return 0
        }

        while let value = wildcard.next() {
            print(value)
        }
        return 0
    }

    private static func intValue(_ value: Any) -> Int? {
        if let n = value as? Int { return n }
        if let n = value as? NSNumber { return n.intValue }
        if let s = value as? String { return Int(s) }
        return nil
    }
}

private extension String {
    func rstrip() -> String {
        var end = endIndex
        while end > startIndex {
            let prev = index(before: end)
            if self[prev].isWhitespace || self[prev].isNewline {
                end = prev
            } else {
                break
            }
        }
        return String(self[..<end])
    }
}
