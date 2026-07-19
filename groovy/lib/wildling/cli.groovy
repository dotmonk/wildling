package wildling

import java.nio.charset.StandardCharsets
import java.nio.file.Files
import java.nio.file.Path

class Cli {
    static class Range {
        final int start
        final int end

        Range(int start, int end) {
            this.start = start
            this.end = end
        }
    }

    static class CliArgs {
        final List<Integer> selects = new ArrayList<>()
        final List<Range> ranges = new ArrayList<>()
        boolean check
        final Map<String, List<String>> dictionaries = new LinkedHashMap<>()
        final List<String> patterns = new ArrayList<>()
        boolean help
        boolean version
    }

    static Range parseRange(String value) {
        int dash = value.indexOf('-')
        if (dash <= 0 || dash == value.length() - 1) {
            return null
        }
        try {
            int start = Integer.parseInt(value.substring(0, dash))
            int end = Integer.parseInt(value.substring(dash + 1))
            return start <= end ? new Range(start, end) : null
        } catch (NumberFormatException ignored) {
            return null
        }
    }

    static List<String> loadDictionaryFile(String path) throws IOException {
        List<String> lines = Files.readAllLines(Path.of(path), StandardCharsets.UTF_8)
        List<String> out = new ArrayList<>()
        for (String line : lines) {
            String trimmed = line.trim()
            if (!trimmed.isEmpty()) {
                out.add(trimmed)
            }
        }
        return out
    }

    @SuppressWarnings("unchecked")
    static void applyDictionary(CliArgs result, String name, Object value) {
        if (value instanceof List) {
            List<String> words = new ArrayList<>()
            for (Object item : (List<Object>) value) {
                words.add(String.valueOf(item))
            }
            result.dictionaries.put(name, words)
            return
        }
        if (value instanceof String) {
            Path path = Path.of((String) value)
            if (Files.exists(path)) {
                try {
                    result.dictionaries.put(name, loadDictionaryFile(path.toString()))
                } catch (IOException ignored) {
                    // ignore unreadable dictionary files
                }
            }
        }
    }

    @SuppressWarnings("unchecked")
    static void applyTemplate(CliArgs result, String path) {
        Path file = Path.of(path)
        if (!Files.exists(file)) {
            System.err.println("Template file not found: " + path)
            System.exit(1)
        }

        Map<String, Object> template
        try {
            String content = Files.readString(file, StandardCharsets.UTF_8)
            template = TemplateJson.parseObject(content)
        } catch (IOException | RuntimeException e) {
            System.err.println("Invalid JSON template: " + path)
            System.exit(1)
            return
        }

        if (Boolean.TRUE.equals(template.get("check"))) {
            result.check = true
        }

        Object select = template.get("select")
        if (select instanceof List) {
            for (Object val : (List<Object>) select) {
                try {
                    int number = val instanceof Number
                            ? ((Number) val).intValue()
                            : Integer.parseInt(String.valueOf(val))
                    if (number >= 0) {
                        result.selects.add(number)
                    }
                } catch (NumberFormatException ignored) {
                    // skip invalid select entries
                }
            }
        }

        Object ranges = template.get("range")
        if (ranges instanceof List) {
            for (Object rangeStr : (List<Object>) ranges) {
                Range parsed = parseRange(String.valueOf(rangeStr))
                if (parsed != null) {
                    result.ranges.add(parsed)
                }
            }
        }

        Object dictionaries = template.get("dictionaries")
        if (dictionaries instanceof Map) {
            for (Map.Entry<String, Object> entry : ((Map<String, Object>) dictionaries).entrySet()) {
                applyDictionary(result, entry.getKey(), entry.getValue())
            }
        }

        Object patterns = template.get("patterns")
        if (patterns instanceof List) {
            for (Object pattern : (List<Object>) patterns) {
                result.patterns.add(String.valueOf(pattern))
            }
        }
    }

    static CliArgs parseArgs(String[] args) {
        CliArgs result = new CliArgs()
        int i = 0
        while (i < args.length) {
            String arg = args[i]

            if ("--help".equals(arg) || "-h".equals(arg)) {
                result.help = true
                i++
                continue
            }
            if ("--version".equals(arg) || "-v".equals(arg)) {
                result.version = true
                i++
                continue
            }
            if ("--check".equals(arg)) {
                result.check = true
                i++
                continue
            }
            if ("--select".equals(arg)) {
                i++
                if (i >= args.length) {
                    break
                }
                try {
                    int val = Integer.parseInt(args[i])
                    if (val >= 0) {
                        result.selects.add(val)
                    }
                } catch (NumberFormatException ignored) {
                    // skip invalid select
                }
                i++
                continue
            }
            if ("--range".equals(arg)) {
                i++
                if (i >= args.length) {
                    break
                }
                Range parsed = parseRange(args[i])
                if (parsed != null) {
                    result.ranges.add(parsed)
                }
                i++
                continue
            }
            if ("--dictionary".equals(arg)) {
                i++
                if (i >= args.length) {
                    break
                }
                String spec = args[i]
                int colon = spec.indexOf(':')
                if (colon > 0 && colon < spec.length() - 1) {
                    applyDictionary(result, spec.substring(0, colon), spec.substring(colon + 1))
                }
                i++
                continue
            }
            if ("--template".equals(arg)) {
                i++
                if (i >= args.length) {
                    System.err.println("Missing path for --template")
                    System.exit(1)
                }
                applyTemplate(result, args[i])
                i++
                continue
            }

            result.patterns.add(arg)
            i++
        }
        return result
    }

    static String loadHelpText() {
        try {
            InputStream inStream = Cli.class.getResourceAsStream("help.txt")
            if (inStream != null) {
                return new String(inStream.readAllBytes(), StandardCharsets.UTF_8)
            }
        } catch (IOException ignored) {
            // fall through
        }

        List<Path> candidates = [
                Path.of("lib", "wildling", "help.txt"),
                Path.of("docs", "help.txt"),
                Path.of("..", "docs", "help.txt"),
        ]
        for (Path path : candidates) {
            if (Files.exists(path)) {
                try {
                    return Files.readString(path, StandardCharsets.UTF_8)
                } catch (IOException ignored) {
                    // try next
                }
            }
        }
        return "wildling - pattern based string generator\n\nHelp text unavailable.\n"
    }

    static String formatList(List<?> values) {
        if (values == null || values.isEmpty()) {
            return ""
        }
        def out = new StringBuilder(" ")
        for (int i = 0; i < values.size(); i++) {
            if (i > 0) {
                out.append(' ')
            }
            out.append(values.get(i))
        }
        return out.toString()
    }

    static String formatCheckOutput(CliArgs args, int total, List<Generator> generators) {
        List<String> rangeStrings = new ArrayList<>()
        for (Range range : args.ranges) {
            rangeStrings.add(range.start + "-" + range.end)
        }
        def out = new StringBuilder()
        out.append("patterns:").append(formatList(args.patterns)).append('\n')
        out.append("dictionaries:").append(formatList(new ArrayList<>(args.dictionaries.keySet()))).append('\n')
        out.append("select:").append(formatList(args.selects)).append('\n')
        out.append("range:").append(formatList(rangeStrings)).append('\n')
        out.append("total: ").append(total)
        for (Generator gen : generators) {
            out.append('\n').append("generator: ").append(gen.source()).append(' ').append(gen.count())
        }
        return out.toString()
    }

    static void main(String[] args) {
        CliArgs parsed = parseArgs(args)

        if (parsed.help) {
            System.out.println(loadHelpText().stripTrailing())
            System.exit(0)
        }

        if (parsed.version) {
            System.out.println("wildling " + Wildling.VERSION)
            System.exit(0)
        }

        if (parsed.patterns.isEmpty()) {
            System.err.println("No pattern provided. Use --help for usage information.")
            System.exit(1)
        }

        Wildling wildcard = Wildling.create(parsed.patterns, parsed.dictionaries)

        if (parsed.check) {
            System.out.println(formatCheckOutput(parsed, wildcard.count(), wildcard.generators()))
            System.exit(0)
        }

        if (!parsed.selects.isEmpty() || !parsed.ranges.isEmpty()) {
            boolean oor = false
            for (int index : parsed.selects) {
                Object value = wildcard.get(index)
                if (Boolean.FALSE.equals(value)) {
                    System.err.println("out of range: " + index)
                    oor = true
                } else {
                    System.out.println(value)
                }
            }
            for (Range range : parsed.ranges) {
                for (int index = range.start; index <= range.end; index++) {
                    Object value = wildcard.get(index)
                    if (Boolean.FALSE.equals(value)) {
                        System.err.println("out of range: " + index)
                        oor = true
                    } else {
                        System.out.println(value)
                    }
                }
            }
            System.exit(oor ? 1 : 0)
        }

        Object value = wildcard.next()
        while (!Boolean.FALSE.equals(value)) {
            System.out.println(value)
            value = wildcard.next()
        }
    }
}
