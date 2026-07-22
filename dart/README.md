# wildling (Dart)

Dart library and CLI for pattern-based string generation. **Zero third-party packages** (`dart:convert` / `dart:io` / `dart:core` only). Requires Dart SDK 3.0+.

## Install

From this repository:

```bash
cd dart
./build.sh
./bin/wildling "foo#"
```

Produces a standalone AOT binary at `dist/wildling`.

**Git:**

```bash
dart pub add wildling \
  --git-url=https://github.com/dotmonk/wildling.git \
  --git-path=dart \
  --git-ref=v2.0.0
```

**Registry:** `dart pub add wildling`

```dart
import 'package:wildling/wildling.dart';

final wildling = Wildling(['foo#']);
var value = wildling.next();
while (value != false) {
  print(value);
  value = wildling.next();
}
```

## CLI

```bash
./bin/wildling "foo#"
./bin/wildling --dictionary planets:../dictionaries/planets.txt "%{'planets'}"
./bin/wildling --template ./config.json
```

Help text and `--check` output follow [`docs/cli.md`](../docs/cli.md) / [`docs/help.txt`](../docs/help.txt).

## Build

```bash
./build.sh   # Docker (dart:stable): dart pub get + compile exe → dist/wildling
```

Project tests live in `../tests/` and are run with `../test.sh`.
