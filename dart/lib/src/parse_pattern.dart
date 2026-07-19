import 'token.dart';

typedef Dictionaries = Map<String, List<String>>;

final _tokenParsingRegex = RegExp(
  r"(\\[%@$*#&?!-]|[%@$*#&?!-]\{.*?\}|[%@$*#&?!-])",
);
final _lengthWithVariants = RegExp(r'\{((\d+)-(\d+)|(\d+))\}');
final _lengthWithString = RegExp(r"\{'(.*)'(?:,(\d+)-(\d+))?(?:,(\d+))?\}");

TokenOptions parseLengthWithVariants(String part, List<String> variants) {
  final match = _lengthWithVariants.firstMatch(part);
  var startLength = 1;
  var endLength = 1;

  if (match != null) {
    if (match.group(2) != null) {
      startLength = int.parse(match.group(2)!);
      endLength = int.parse(match.group(3)!);
    } else if (match.group(1) != null) {
      startLength = int.parse(match.group(1)!);
      endLength = startLength;
    }
  }

  return TokenOptions(
    variants: variants,
    startLength: startLength,
    endLength: endLength,
    src: part,
  );
}

TokenOptions? parseLengthWithString(String part) {
  final match = _lengthWithString.firstMatch(part);
  if (match == null) {
    return null;
  }

  final string = match.group(1) ?? '';
  if (match.group(2) != null && match.group(3) != null) {
    return TokenOptions(
      string: string,
      startLength: int.parse(match.group(2)!),
      endLength: int.parse(match.group(3)!),
      src: part,
    );
  }

  if (match.group(4) != null) {
    final length = int.parse(match.group(4)!);
    return TokenOptions(
      string: string,
      startLength: length,
      endLength: length,
      src: part,
    );
  }

  return TokenOptions(
    string: string,
    startLength: 1,
    endLength: 1,
    src: part,
  );
}

Token Function(String) simpleTokenizer(String variantsString) {
  final variants = variantsString.split('');
  return (part) => Token(parseLengthWithVariants(part, variants));
}

Token dictionaryTokenizer(String part, Dictionaries dictionaries) {
  var options = parseLengthWithString(part);
  final key = options?.string;
  if (options == null ||
      (key != null && key.isNotEmpty && !dictionaries.containsKey(key))) {
    options = TokenOptions(
      variants: [part],
      startLength: 1,
      endLength: 1,
      src: part,
    );
  } else {
    options.variants = dictionaries[key ?? ''] ?? const [];
  }
  return Token(options);
}

Token wordsTokenizer(String part) {
  var options = parseLengthWithString(part);
  if (options == null) {
    options = TokenOptions(
      variants: [part],
      startLength: 1,
      endLength: 1,
      src: part,
    );
  } else {
    final variants = <String>[];
    var workString = options.string ?? '';
    var index = 0;
    while (index < workString.length) {
      if (index + 1 < workString.length &&
          workString[index] == '\\' &&
          workString[index + 1] == ',') {
        index += 2;
      } else if (workString[index] == ',') {
        variants.add(workString.substring(0, index));
        workString = workString.substring(index + 1);
        index = 0;
      } else {
        index += 1;
      }
    }
    variants.add(workString);
    options.variants =
        variants.map((variant) => variant.replaceAll(r'\,', ',')).toList();
  }
  return Token(options);
}

Token partToToken(String part, Dictionaries dictionaries) {
  final tokenizers = <String, Token Function(String)>{
    '#': simpleTokenizer('0123456789'),
    '@': simpleTokenizer('abcdefghijklmnopqrstuvwxyz'),
    '*': simpleTokenizer('abcdefghijklmnopqrstuvwxyz0123456789'),
    '-': simpleTokenizer(
      'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789',
    ),
    '!': simpleTokenizer('ABCDEFGHIJKLMNOPQRSTUVWXYZ'),
    '?': simpleTokenizer('ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'),
    '&': simpleTokenizer('abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'),
    '%': (p) => dictionaryTokenizer(p, dictionaries),
    r'$': wordsTokenizer,
  };

  final tokenizer = part.isNotEmpty ? tokenizers[part[0]] : null;
  final isEscaped =
      part.length > 1 && part[0] == '\\' && tokenizers.containsKey(part[1]);

  if (tokenizer != null) {
    return tokenizer(part);
  }
  if (isEscaped) {
    return Token(
      TokenOptions(
        variants: [part.substring(1)],
        startLength: 1,
        endLength: 1,
        src: part,
      ),
    );
  }
  return Token(
    TokenOptions(
      variants: [part],
      startLength: 1,
      endLength: 1,
      src: part,
    ),
  );
}

/// Split like JS/Python capturing-group split (Dart RegExp.split does not).
List<String> splitKeepingDelimiters(String input) {
  final parts = <String>[];
  var last = 0;
  for (final match in _tokenParsingRegex.allMatches(input)) {
    if (match.start > last) {
      final before = input.substring(last, match.start);
      if (before.isNotEmpty) {
        parts.add(before);
      }
    }
    final token = match.group(1);
    if (token != null && token.isNotEmpty) {
      parts.add(token);
    }
    last = match.end;
  }
  if (last < input.length) {
    final rest = input.substring(last);
    if (rest.isNotEmpty) {
      parts.add(rest);
    }
  }
  return parts;
}

List<Token> parsePattern(String inputPattern, Dictionaries? dictionaries) {
  final dicts = dictionaries ?? <String, List<String>>{};
  return splitKeepingDelimiters(inputPattern)
      .map((part) => partToToken(part, dicts))
      .toList();
}
