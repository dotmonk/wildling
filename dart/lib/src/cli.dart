import 'dart:convert';
import 'dart:io';

import 'generator.dart';
import 'parse_pattern.dart';
import 'wildling.dart';

class CliRange {
  final int start;
  final int end;
  CliRange(this.start, this.end);
}

class CliArgs {
  final List<int> selects = [];
  final List<CliRange> ranges = [];
  bool check = false;
  final Dictionaries dictionaries = {};
  final List<String> patterns = [];
  bool help = false;
  bool versionFlag = false;
}

CliRange? parseRange(String value) {
  final dash = value.indexOf('-');
  if (dash <= 0 || dash == value.length - 1) {
    return null;
  }
  final startStr = value.substring(0, dash);
  final endStr = value.substring(dash + 1);
  if (!_isDigits(startStr) || !_isDigits(endStr)) {
    return null;
  }
  final start = int.parse(startStr);
  final end = int.parse(endStr);
  return start <= end ? CliRange(start, end) : null;
}

bool _isDigits(String value) =>
    value.isNotEmpty && value.runes.every((r) => r >= 48 && r <= 57);

List<String> loadDictionaryFile(String path) {
  return File(path)
      .readAsStringSync()
      .split(RegExp(r'\r?\n'))
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();
}

void applyDictionary(CliArgs result, String name, Object value) {
  if (value is List) {
    result.dictionaries[name] = value.map((item) => item.toString()).toList();
    return;
  }
  if (value is String && File(value).existsSync()) {
    try {
      result.dictionaries[name] = loadDictionaryFile(value);
    } catch (_) {
      // ignore unreadable dictionary files
    }
  }
}

void applyTemplate(CliArgs result, String path) {
  if (!File(path).existsSync()) {
    stderr.writeln('Template file not found: $path');
    exit(1);
  }

  Map<String, dynamic> template;
  try {
    final content = File(path).readAsStringSync();
    final decoded = jsonDecode(content);
    if (decoded is! Map<String, dynamic>) {
      stderr.writeln('Invalid JSON template: $path');
      exit(1);
    }
    template = decoded;
  } catch (_) {
    stderr.writeln('Invalid JSON template: $path');
    exit(1);
  }

  if (template['check'] == true) {
    result.check = true;
  }

  final select = template['select'];
  if (select is List) {
    for (final val in select) {
      try {
        final number = val is num ? val.toInt() : int.parse(val.toString());
        if (number >= 0) {
          result.selects.add(number);
        }
      } catch (_) {
        // skip invalid select entries
      }
    }
  }

  final ranges = template['range'];
  if (ranges is List) {
    for (final rangeStr in ranges) {
      final parsed = parseRange(rangeStr.toString());
      if (parsed != null) {
        result.ranges.add(parsed);
      }
    }
  }

  final dictionaries = template['dictionaries'];
  if (dictionaries is Map) {
    dictionaries.forEach((name, value) {
      if (value is String || value is List) {
        applyDictionary(result, name.toString(), value);
      }
    });
  }

  final patterns = template['patterns'];
  if (patterns is List) {
    for (final pattern in patterns) {
      result.patterns.add(pattern.toString());
    }
  }
}

CliArgs parseArgs(List<String> args) {
  final result = CliArgs();
  var i = 0;
  while (i < args.length) {
    final arg = args[i];
    if (arg == '--help' || arg == '-h') {
      result.help = true;
      i += 1;
      continue;
    }
    if (arg == '--version' || arg == '-v') {
      result.versionFlag = true;
      i += 1;
      continue;
    }
    if (arg == '--check') {
      result.check = true;
      i += 1;
      continue;
    }
    if (arg == '--select') {
      i += 1;
      if (i >= args.length) {
        break;
      }
      final val = int.tryParse(args[i]) ?? -1;
      if (val >= 0) {
        result.selects.add(val);
      }
      i += 1;
      continue;
    }
    if (arg == '--range') {
      i += 1;
      if (i >= args.length) {
        break;
      }
      final parsed = parseRange(args[i]);
      if (parsed != null) {
        result.ranges.add(parsed);
      }
      i += 1;
      continue;
    }
    if (arg == '--dictionary') {
      i += 1;
      if (i >= args.length) {
        break;
      }
      final colon = args[i].indexOf(':');
      if (colon > 0 && colon < args[i].length - 1) {
        applyDictionary(
          result,
          args[i].substring(0, colon),
          args[i].substring(colon + 1),
        );
      }
      i += 1;
      continue;
    }
    if (arg == '--template') {
      i += 1;
      if (i >= args.length) {
        stderr.writeln('Missing path for --template');
        exit(1);
      }
      applyTemplate(result, args[i]);
      i += 1;
      continue;
    }
    result.patterns.add(arg);
    i += 1;
  }
  return result;
}

String loadHelpText() {
  final candidates = <String>[];
  try {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    candidates.add('$exeDir/help.txt');
    candidates.add('$exeDir/../docs/help.txt');
  } catch (_) {}
  candidates.add('docs/help.txt');

  for (final path in candidates) {
    final file = File(path);
    if (file.existsSync()) {
      return file.readAsStringSync();
    }
  }
  return 'wildling - pattern based string generator\n\nHelp text unavailable.\n';
}

String formatList(List<Object> values) =>
    values.isEmpty ? '' : ' ${values.map((v) => v.toString()).join(' ')}';

String formatCheckOutput(CliArgs args, int total, List<Generator> generators) {
  final rangeStrings =
      args.ranges.map((r) => '${r.start}-${r.end}').toList();
  final lines = <String>[
    'patterns:${formatList(args.patterns)}',
    'dictionaries:${formatList(args.dictionaries.keys.toList())}',
    'select:${formatList(args.selects)}',
    'range:${formatList(rangeStrings)}',
    'total: $total',
  ];
  for (final gen in generators) {
    lines.add('generator: ${gen.source} ${gen.count()}');
  }
  return lines.join('\n');
}

void runCli(List<String> argv) {
  final args = parseArgs(argv);

  if (args.help) {
    stdout.writeln(loadHelpText().trimRight());
    exit(0);
  }

  if (args.versionFlag) {
    stdout.writeln('wildling $version');
    exit(0);
  }

  if (args.patterns.isEmpty) {
    stderr.writeln('No pattern provided. Use --help for usage information.');
    exit(1);
  }

  final wildcard = Wildling(args.patterns, args.dictionaries);

  if (args.check) {
    stdout.writeln(
      formatCheckOutput(args, wildcard.count(), wildcard.generators()),
    );
    exit(0);
  }

  if (args.selects.isNotEmpty || args.ranges.isNotEmpty) {
    for (final index in args.selects) {
      stdout.writeln(wildcard.get(index));
    }
    for (final range in args.ranges) {
      for (var index = range.start; index <= range.end; index++) {
        stdout.writeln(wildcard.get(index));
      }
    }
    exit(0);
  }

  var value = wildcard.next();
  while (value != false) {
    stdout.writeln(value);
    value = wildcard.next();
  }
}
