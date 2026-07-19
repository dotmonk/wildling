class TokenOptions {
  String? string;
  int? startLength;
  int? endLength;
  List<String>? variants;
  String? src;

  TokenOptions({
    this.string,
    this.startLength,
    this.endLength,
    this.variants,
    this.src,
  });
}

class Token {
  final String _src;
  final int _startLength;
  final int _endLength;
  final List<String> _variants;
  final int _count;

  Token(TokenOptions options)
      : _src = options.src ?? '',
        _startLength = _defaultInteger(options.startLength, 1),
        _endLength = _defaultInteger(options.endLength, 1),
        _variants = List<String>.from(options.variants ?? const []),
        _count = _computeCount(
          _defaultInteger(options.startLength, 1),
          _defaultInteger(options.endLength, 1),
          options.variants ?? const [],
        );

  static int _defaultInteger(int? option, int fallback) =>
      option != null && option >= 0 ? option : fallback;

  static int _pow(int base, int exp) {
    var result = 1;
    for (var i = 0; i < exp; i++) {
      result *= base;
    }
    return result;
  }

  static int _computeCount(int startLength, int endLength, List<String> variants) {
    var total = 0;
    for (var length = startLength; length <= endLength; length++) {
      total += _pow(variants.length, length);
    }
    return total;
  }

  int count() => _count;

  String src() => _src;

  String get(int index) {
    if (index > _count - 1 || index < 0) {
      return '';
    }
    if (index == 0 && _startLength == 0) {
      return '';
    }

    var indexWithOffset = index;
    var stringLength = _startLength;
    for (stringLength = _startLength; stringLength <= _endLength; stringLength++) {
      final offsetCount = _pow(_variants.length, stringLength);
      if (indexWithOffset < offsetCount) {
        break;
      }
      indexWithOffset -= offsetCount;
    }

    final stringArray = <String>[];
    for (var i = 0; i < stringLength; i++) {
      final variantIndex = indexWithOffset % _variants.length;
      indexWithOffset ~/= _variants.length;
      stringArray.add(_variants[variantIndex]);
    }
    return stringArray.join();
  }
}
