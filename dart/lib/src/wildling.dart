import 'generator.dart';
import 'parse_pattern.dart';

const version = '2.0.0';

class Wildling {
  final List<Generator> _generators;
  final int _patternCount;
  int _internalIndex = 0;

  factory Wildling(List<String> patterns, [Dictionaries? dictionaries]) {
    final dicts = dictionaries ?? <String, List<String>>{};
    final generators = <Generator>[];
    var total = 0;
    for (final pattern in patterns) {
      final generator = Generator(pattern, dicts);
      generators.add(generator);
      total += generator.count();
    }
    return Wildling._(generators, total);
  }

  Wildling._(this._generators, this._patternCount);

  int index() => _internalIndex;

  int count() => _patternCount;

  void reset() {
    _internalIndex = 0;
  }

  /// Next combination, or `false` when exhausted.
  Object next() {
    if (_internalIndex == _patternCount) {
      return false;
    }
    _internalIndex += 1;
    return get(_internalIndex - 1);
  }

  List<Generator> generators() => _generators;

  /// Combination at index, or `false` if out of range.
  Object get(int index) {
    if (index > _patternCount - 1 || index < 0) {
      return false;
    }
    var segmentIndex = 0;
    for (final generator in _generators) {
      final patternIndex = index - segmentIndex;
      if (patternIndex < generator.count()) {
        return generator.get(patternIndex);
      }
      segmentIndex += generator.count();
    }
    return false;
  }
}
