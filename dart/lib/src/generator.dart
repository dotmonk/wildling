import 'parse_pattern.dart';
import 'token.dart';

class Generator {
  final String source;
  final List<Token> _tokens;
  final int _count;

  factory Generator(String inputPattern, Dictionaries? dictionaries) {
    final tokens = parsePattern(inputPattern, dictionaries);
    var total = 1;
    for (final token in tokens) {
      total *= token.count();
    }
    return Generator._(inputPattern, tokens, total);
  }

  Generator._(this.source, this._tokens, this._count);

  int count() => _count;

  List<Token> tokens() => _tokens;

  String get(int index) {
    if (index > _count - 1 || index < 0) {
      return '';
    }
    final stringArray = <String>[];
    var indexWithOffset = index;
    for (final token in _tokens) {
      stringArray.add(token.get(indexWithOffset % token.count()));
      indexWithOffset ~/= token.count();
    }
    return stringArray.join();
  }
}
