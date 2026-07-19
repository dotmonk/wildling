package wildling

import java.nio.charset.StandardCharsets
import java.nio.file.Files
import java.nio.file.Path
import kotlin.system.exitProcess

object Cli {
    data class Range(val start: Int, val end: Int)

    class CliArgs {
        val selects = mutableListOf<Int>()
        val ranges = mutableListOf<Range>()
        var check: Boolean = false
        val dictionaries = linkedMapOf<String, List<String>>()
        val patterns = mutableListOf<String>()
        var help: Boolean = false
        var version: Boolean = false
    }

    fun parseRange(value: String): Range? {
        val dash = value.indexOf('-')
        if (dash <= 0 || dash == value.length - 1) {
            return null
        }
        return try {
            val start = value.substring(0, dash).toInt()
            val end = value.substring(dash + 1).toInt()
            if (start <= end) Range(start, end) else null
        } catch (_: NumberFormatException) {
            null
        }
    }

    fun loadDictionaryFile(path: String): List<String> =
        Files.readAllLines(Path.of(path), StandardCharsets.UTF_8)
            .map { it.trim() }
            .filter { it.isNotEmpty() }

    @Suppress("UNCHECKED_CAST")
    fun applyDictionary(result: CliArgs, name: String, value: Any?) {
        when (value) {
            is List<*> -> {
                result.dictionaries[name] = value.map { it.toString() }
            }
            is String -> {
                val path = Path.of(value)
                if (Files.exists(path)) {
                    try {
                        result.dictionaries[name] = loadDictionaryFile(path.toString())
                    } catch (_: Exception) {
                        // ignore unreadable dictionary files
                    }
                }
            }
        }
    }

    @Suppress("UNCHECKED_CAST")
    fun applyTemplate(result: CliArgs, path: String) {
        val file = Path.of(path)
        if (!Files.exists(file)) {
            System.err.println("Template file not found: $path")
            exitProcess(1)
        }

        val template: Map<String, Any?>
        try {
            val content = Files.readString(file, StandardCharsets.UTF_8)
            template = TemplateJson.parseObject(content)
        } catch (_: Exception) {
            System.err.println("Invalid JSON template: $path")
            exitProcess(1)
        }

        if (template["check"] == true) {
            result.check = true
        }

        val select = template["select"]
        if (select is List<*>) {
            for (item in select) {
                try {
                    val number = when (item) {
                        is Number -> item.toInt()
                        else -> item.toString().toInt()
                    }
                    if (number >= 0) {
                        result.selects.add(number)
                    }
                } catch (_: NumberFormatException) {
                    // skip invalid select entries
                }
            }
        }

        val ranges = template["range"]
        if (ranges is List<*>) {
            for (rangeStr in ranges) {
                val parsed = parseRange(rangeStr.toString())
                if (parsed != null) {
                    result.ranges.add(parsed)
                }
            }
        }

        val dictionaries = template["dictionaries"]
        if (dictionaries is Map<*, *>) {
            for ((key, value) in dictionaries) {
                applyDictionary(result, key.toString(), value)
            }
        }

        val patterns = template["patterns"]
        if (patterns is List<*>) {
            for (pattern in patterns) {
                result.patterns.add(pattern.toString())
            }
        }
    }

    fun parseArgs(args: Array<String>): CliArgs {
        val result = CliArgs()
        var i = 0
        while (i < args.size) {
            when (val arg = args[i]) {
                "--help", "-h" -> {
                    result.help = true
                    i++
                }
                "--version", "-v" -> {
                    result.version = true
                    i++
                }
                "--check" -> {
                    result.check = true
                    i++
                }
                "--select" -> {
                    i++
                    if (i >= args.size) break
                    try {
                        val value = args[i].toInt()
                        if (value >= 0) {
                            result.selects.add(value)
                        }
                    } catch (_: NumberFormatException) {
                        // skip invalid select
                    }
                    i++
                }
                "--range" -> {
                    i++
                    if (i >= args.size) break
                    val parsed = parseRange(args[i])
                    if (parsed != null) {
                        result.ranges.add(parsed)
                    }
                    i++
                }
                "--dictionary" -> {
                    i++
                    if (i >= args.size) break
                    val spec = args[i]
                    val colon = spec.indexOf(':')
                    if (colon > 0 && colon < spec.length - 1) {
                        applyDictionary(
                            result,
                            spec.substring(0, colon),
                            spec.substring(colon + 1),
                        )
                    }
                    i++
                }
                "--template" -> {
                    i++
                    if (i >= args.size) {
                        System.err.println("Missing path for --template")
                        exitProcess(1)
                    }
                    applyTemplate(result, args[i])
                    i++
                }
                else -> {
                    result.patterns.add(arg)
                    i++
                }
            }
        }
        return result
    }

    fun loadHelpText(): String {
        val resource = Cli::class.java.getResourceAsStream("help.txt")
        if (resource != null) {
            resource.use {
                return String(it.readAllBytes(), StandardCharsets.UTF_8)
            }
        }
        val fallback = Path.of("docs", "help.txt")
        if (Files.exists(fallback)) {
            return Files.readString(fallback, StandardCharsets.UTF_8)
        }
        return "wildling - pattern based string generator\n\nHelp text unavailable.\n"
    }

    fun formatList(values: List<*>?): String {
        if (values.isNullOrEmpty()) {
            return ""
        }
        return " " + values.joinToString(" ")
    }

    fun formatCheckOutput(args: CliArgs, total: Int, generators: List<Generator>): String {
        val rangeStrings = args.ranges.map { "${it.start}-${it.end}" }
        val lines = mutableListOf(
            "patterns:${formatList(args.patterns)}",
            "dictionaries:${formatList(args.dictionaries.keys.toList())}",
            "select:${formatList(args.selects)}",
            "range:${formatList(rangeStrings)}",
            "total: $total",
        )
        for (gen in generators) {
            lines.add("generator: ${gen.source} ${gen.count()}")
        }
        return lines.joinToString("\n")
    }
}

fun main(args: Array<String>) {
    val parsed = Cli.parseArgs(args)

    if (parsed.help) {
        println(Cli.loadHelpText().trimEnd())
        exitProcess(0)
    }

    if (parsed.version) {
        println("wildling ${Wildling.VERSION}")
        exitProcess(0)
    }

    if (parsed.patterns.isEmpty()) {
        System.err.println("No pattern provided. Use --help for usage information.")
        exitProcess(1)
    }

    val wildcard = Wildling.create(parsed.patterns, parsed.dictionaries)

    if (parsed.check) {
        println(Cli.formatCheckOutput(parsed, wildcard.count(), wildcard.generators()))
        exitProcess(0)
    }

    if (parsed.selects.isNotEmpty() || parsed.ranges.isNotEmpty()) {
        var oor = false
        for (index in parsed.selects) {
            val value = wildcard.get(index)
            if (value == false) {
                System.err.println("out of range: $index")
                oor = true
            } else {
                println(value)
            }
        }
        for (range in parsed.ranges) {
            for (index in range.start..range.end) {
                val value = wildcard.get(index)
                if (value == false) {
                    System.err.println("out of range: $index")
                    oor = true
                } else {
                    println(value)
                }
            }
        }
        exitProcess(if (oor) 1 else 0)
    }

    var value = wildcard.next()
    while (value != false) {
        println(value)
        value = wildcard.next()
    }
}
