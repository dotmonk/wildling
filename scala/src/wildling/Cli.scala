package wildling

import java.nio.charset.StandardCharsets
import java.nio.file.{Files, Path}
import scala.collection.mutable
import scala.collection.mutable.ArrayBuffer
import scala.io.Source
import scala.util.Try

final case class CliRange(start: Int, end: Int)

final class CliArgs {
  val selects: ArrayBuffer[Int] = ArrayBuffer.empty
  val ranges: ArrayBuffer[CliRange] = ArrayBuffer.empty
  var check: Boolean = false
  val dictionaries: mutable.LinkedHashMap[String, Seq[String]] =
    mutable.LinkedHashMap.empty
  val patterns: ArrayBuffer[String] = ArrayBuffer.empty
  var help: Boolean = false
  var version: Boolean = false
}

object Cli {
  def parseRange(value: String): Option[CliRange] = {
    val dash = value.indexOf('-')
    if (dash <= 0 || dash == value.length - 1) return None
    Try {
      val start = value.substring(0, dash).toInt
      val end = value.substring(dash + 1).toInt
      if (
        value.substring(0, dash).forall(_.isDigit) &&
        value.substring(dash + 1).forall(_.isDigit) &&
        start <= end
      ) Some(CliRange(start, end))
      else None
    }.getOrElse(None)
  }

  def loadDictionaryFile(path: String): Seq[String] = {
    val source = Source.fromFile(path, "UTF-8")
    try {
      source.getLines().map(_.trim).filter(_.nonEmpty).toSeq
    } finally {
      source.close()
    }
  }

  def applyDictionary(result: CliArgs, name: String, value: Any): Unit = {
    value match {
      case list: Seq[_] =>
        result.dictionaries(name) = list.map(_.toString)
      case list: java.util.List[_] =>
        val buf = ArrayBuffer.empty[String]
        val it = list.iterator()
        while (it.hasNext) buf += String.valueOf(it.next())
        result.dictionaries(name) = buf.toSeq
      case path: String =>
        if (Files.exists(Path.of(path))) {
          Try(loadDictionaryFile(path)).foreach { words =>
            result.dictionaries(name) = words
          }
        }
      case _ =>
    }
  }

  def applyTemplate(result: CliArgs, path: String): Unit = {
    val file = Path.of(path)
    if (!Files.exists(file)) {
      System.err.println(s"Template file not found: $path")
      sys.exit(1)
    }

    val template =
      try {
        val content = Files.readString(file, StandardCharsets.UTF_8)
        TemplateJson.parseObject(content)
      } catch {
        case _: Exception =>
          System.err.println(s"Invalid JSON template: $path")
          sys.exit(1)
          return
      }

    template.get("check") match {
      case Some(true) => result.check = true
      case _ =>
    }

    template.get("select") match {
      case Some(select: Seq[_]) =>
        select.foreach { raw =>
          Try {
            val number = raw match {
              case n: Number => n.intValue()
              case other => other.toString.toInt
            }
            if (number >= 0) result.selects += number
          }
        }
      case _ =>
    }

    template.get("range") match {
      case Some(ranges: Seq[_]) =>
        ranges.foreach { rangeStr =>
          parseRange(rangeStr.toString).foreach(result.ranges += _)
        }
      case _ =>
    }

    template.get("dictionaries") match {
      case Some(dictionaries: mutable.LinkedHashMap[_, _]) =>
        dictionaries.foreach { case (name, value) =>
          applyDictionary(result, name.toString, value)
        }
      case Some(dictionaries: Map[_, _]) =>
        dictionaries.foreach { case (name, value) =>
          applyDictionary(result, name.toString, value)
        }
      case _ =>
    }

    template.get("patterns") match {
      case Some(patterns: Seq[_]) =>
        patterns.foreach(p => result.patterns += p.toString)
      case _ =>
    }
  }

  def parseArgs(args: Array[String]): CliArgs = {
    val result = new CliArgs
    var i = 0
    while (i < args.length) {
      args(i) match {
        case "--help" | "-h" =>
          result.help = true
          i += 1
        case "--version" | "-v" =>
          result.version = true
          i += 1
        case "--check" =>
          result.check = true
          i += 1
        case "--select" =>
          i += 1
          if (i >= args.length) return result
          Try(args(i).toInt).foreach { value =>
            if (value >= 0) result.selects += value
          }
          i += 1
        case "--range" =>
          i += 1
          if (i >= args.length) return result
          parseRange(args(i)).foreach(result.ranges += _)
          i += 1
        case "--dictionary" =>
          i += 1
          if (i >= args.length) return result
          val spec = args(i)
          val colon = spec.indexOf(':')
          if (colon > 0 && colon < spec.length - 1) {
            applyDictionary(
              result,
              spec.substring(0, colon),
              spec.substring(colon + 1)
            )
          }
          i += 1
        case "--template" =>
          i += 1
          if (i >= args.length) {
            System.err.println("Missing path for --template")
            sys.exit(1)
          }
          applyTemplate(result, args(i))
          i += 1
        case arg =>
          result.patterns += arg
          i += 1
      }
    }
    result
  }

  def loadHelpText(): String = {
    val stream = getClass.getResourceAsStream("help.txt")
    if (stream != null) {
      try {
        new String(stream.readAllBytes(), StandardCharsets.UTF_8)
      } finally {
        stream.close()
      }
    } else {
      val fallback = Path.of("docs", "help.txt")
      if (Files.exists(fallback)) {
        Files.readString(fallback, StandardCharsets.UTF_8)
      } else {
        "wildling - pattern based string generator\n\nHelp text unavailable.\n"
      }
    }
  }

  def formatList(values: Seq[Any]): String =
    if (values == null || values.isEmpty) ""
    else " " + values.map(_.toString).mkString(" ")

  def formatCheckOutput(args: CliArgs, total: Int, generators: Seq[Generator]): String = {
    val rangeStrings = args.ranges.map(r => s"${r.start}-${r.end}")
    val lines = ArrayBuffer(
      s"patterns:${formatList(args.patterns.toSeq)}",
      s"dictionaries:${formatList(args.dictionaries.keys.toSeq)}",
      s"select:${formatList(args.selects.toSeq)}",
      s"range:${formatList(rangeStrings.toSeq)}",
      s"total: $total"
    )
    generators.foreach { gen =>
      lines += s"generator: ${gen.source} ${gen.count()}"
    }
    lines.mkString("\n")
  }

  def main(args: Array[String]): Unit = {
    val parsed = parseArgs(args)

    if (parsed.help) {
      println(loadHelpText().replaceAll("\\s+$", ""))
      sys.exit(0)
    }

    if (parsed.version) {
      println(s"wildling ${Wildling.Version}")
      sys.exit(0)
    }

    if (parsed.patterns.isEmpty) {
      System.err.println("No pattern provided. Use --help for usage information.")
      sys.exit(1)
    }

    val wildcard = Wildling(parsed.patterns.toSeq, parsed.dictionaries.toMap)

    if (parsed.check) {
      println(formatCheckOutput(parsed, wildcard.count(), wildcard.generators()))
      sys.exit(0)
    }

    if (parsed.selects.nonEmpty || parsed.ranges.nonEmpty) {
      parsed.selects.foreach(index => println(wildcard.get(index)))
      parsed.ranges.foreach { range =>
        var index = range.start
        while (index <= range.end) {
          println(wildcard.get(index))
          index += 1
        }
      }
      sys.exit(0)
    }

    var value = wildcard.next()
    while (value != false) {
      println(value)
      value = wildcard.next()
    }
  }
}
