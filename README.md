# wildling

<p align="center">
  <img src="assets/logo.svg" alt="wildling" width="112" height="112" />
</p>

<p align="center">
  <a href="https://github.com/dotmonk/wildling/actions/workflows/test.yml"><img src="https://github.com/dotmonk/wildling/actions/workflows/test.yml/badge.svg" alt="Test" /></a>
  <a href="https://dotmonk.github.io/wildling/"><img src="https://img.shields.io/badge/docs-GitHub%20Pages-c8f542?labelColor=0c1210" alt="Docs" /></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-c5d4c8?labelColor=0c1210" alt="MIT" /></a>
</p>

<p align="center">
  <a href="https://dotmonk.github.io/wildling/">Website</a>
  ·
  <a href="https://dotmonk.github.io/wildling/syntax.html">Syntax</a>
  ·
  <a href="https://dotmonk.github.io/wildling/sandbox.html">Sandbox</a>
  ·
  <a href="CONTRIBUTING.md">Contributing</a>
</p>

Pattern-based string generator — library and CLI in many languages, one shared
grammar. Enumerate combinations for wordlists, domain brainstorming, test data,
and similar tasks.

**Requirements:** Docker for language builds; Node 18+ only for the JavaScript
port and the documentation site.

## Website

Docs and a live browser sandbox are published with GitHub Pages:

- [Home (language wall)](https://dotmonk.github.io/wildling/)
- [Pattern syntax](https://dotmonk.github.io/wildling/syntax.html)
- [Sandbox](https://dotmonk.github.io/wildling/sandbox.html)

Build the site locally with `./scripts/build-site.sh` (output in `_site/`). In the repo **Settings → Pages**, set the source to **GitHub Actions**.

## Status

| Language | Library | CLI |
|----------|---------|-----|
| [JavaScript / TypeScript](javascript/) | Yes | Yes |
| [Python](python/) | Yes | Yes |
| [Java](java/) | Yes | Yes |
| [C#](csharp/) | Yes | Yes |
| [Visual Basic / VB.NET](visualbasic/) | Yes | Yes |
| [C++](cpp/) | Yes | Yes |
| [PHP](php/) | Yes | Yes |
| [C](c/) | Yes | Yes |
| [Go](go/) | Yes | Yes |
| [Rust](rust/) | Yes | Yes |
| [Kotlin](kotlin/) | Yes | Yes |
| [Ruby](ruby/) | Yes | Yes |
| [Swift](swift/) | Yes | Yes |
| [Scala](scala/) | Yes | Yes |
| [Dart](dart/) | Yes | Yes |
| [POSIX shell](posix-shell/) | Yes | Yes |
| [PowerShell](powershell/) | Yes | Yes |
| [Lua](lua/) | Yes | Yes |
| [Assembly (x86-64 NASM)](assembly/) | Yes | Yes |
| [R](r/) | Yes | Yes |
| [Groovy](groovy/) | Yes | Yes |
| [Perl](perl/) | Yes | Yes |
| [Elixir](elixir/) | Yes | Yes |
| [Pascal / Free Pascal](pascal/) | Yes | Yes |
| [Zig](zig/) | Yes | Yes |
| [Fortran](fortran/) | Yes | Yes |
| [Ada](ada/) | Yes | Yes |
| [F#](fsharp/) | Yes | Yes |
| [Haskell](haskell/) | Yes | Yes |

## Quick start (JavaScript)

```bash
cd javascript && npm ci --include=dev && npm run build
./bin/wildling "foo#"
```

```
foo0
foo1
…
foo9
```

As a library (from this repo):

```js
const createWildling = require("./javascript/dist/index.js").default;

const wildling = createWildling({
  patterns: ["foo#"],
  dictionaries: {},
});

let value;
while ((value = wildling.next())) {
  console.log(value);
}
```

## Quick start (Python)

```bash
cd python && ./build.sh
./bin/wildling "foo#"
```

```python
from wildling import create_wildling

wildling = create_wildling(patterns=["foo#"])
value = wildling.next()
while value is not False:
    print(value)
    value = wildling.next()
```

## Quick start (Java)

```bash
cd java && ./build.sh
./bin/wildling "foo#"
```

```java
import wildling.Wildling;
import java.util.List;

Wildling wildling = Wildling.create(List.of("foo#"));
Object value = wildling.next();
while (!Boolean.FALSE.equals(value)) {
    System.out.println(value);
    value = wildling.next();
}
```

## Quick start (C#)

```bash
cd csharp && ./build.sh
./bin/wildling "foo#"
```

```csharp
using WildlingLib;

var wildling = Wildling.Create(new[] { "foo#" });
object value = wildling.Next();
while (value is not false)
{
    Console.WriteLine(value);
    value = wildling.Next();
}
```

## Quick start (Visual Basic / VB.NET)

```bash
cd visualbasic && ./build.sh
./bin/wildling "foo#"
```

```vb
Imports WildlingLib

Dim wildling = Wildling.Create({"foo#"})
Dim value As Object = wildling.Next()
While Not (TypeOf value Is Boolean AndAlso Not CBool(value))
    Console.WriteLine(value)
    value = wildling.Next()
End While
```

## Quick start (C++)

```bash
cd cpp && ./build.sh
./bin/wildling "foo#"
```

```cpp
#include "wildling.hpp"
#include <iostream>

wildling::Dictionaries dictionaries;
wildling::Wildling w({"foo#"}, dictionaries);
auto value = w.next();
while (value.has_value()) {
    std::cout << *value << '\n';
    value = w.next();
}
```

## Quick start (PHP)

```bash
cd php && ./build.sh
./bin/wildling "foo#"
```

```php
<?php
require 'php/bootstrap.php';

use Wildling\Wildling;

$wildling = Wildling::create(['foo#']);
$value = $wildling->next();
while ($value !== false) {
    echo $value, "\n";
    $value = $wildling->next();
}
```

## Quick start (C)

```bash
cd c && ./build.sh
./bin/wildling "foo#"
```

## Quick start (Go)

```bash
cd go && ./build.sh
./bin/wildling "foo#"
```

```go
import "github.com/dotmonk/wildling/go/wildling"

w := wildling.New([]string{"foo#"}, nil)
for {
    value, ok := w.Next()
    if !ok {
        break
    }
    fmt.Println(value)
}
```

## Quick start (Rust)

```bash
cd rust && ./build.sh
./bin/wildling "foo#"
```

```rust
use wildling::{Dictionaries, Wildling};

let dicts = Dictionaries::new();
let mut w = Wildling::new(&["foo#".to_string()], &dicts);
while let Some(value) = w.next() {
    println!("{value}");
}
```

## Quick start (Kotlin)

```bash
cd kotlin && ./build.sh
./bin/wildling "foo#"
```

```kotlin
import wildling.Wildling

val wildling = Wildling.create(listOf("foo#"))
var value = wildling.next()
while (value != false) {
    println(value)
    value = wildling.next()
}
```

## Quick start (Ruby)

```bash
cd ruby && ./build.sh
./bin/wildling "foo#"
```

```ruby
require_relative "lib/wildling"

wildling = Wildling.create(["foo#"])
value = wildling.next
while value != false
  puts value
  value = wildling.next
end
```

## Quick start (Swift)

```bash
cd swift && ./build.sh
./bin/wildling "foo#"
```

```swift
let wildling = Wildling(patterns: ["foo#"])
while let value = wildling.next() {
    print(value)
}
```

## Quick start (Scala)

```bash
cd scala && ./build.sh
./bin/wildling "foo#"
```

```scala
val wildling = Wildling(Seq("foo#"))
var value = wildling.next()
while (value != false) {
  println(value)
  value = wildling.next()
}
```

## Quick start (Dart)

```bash
cd dart && ./build.sh
./bin/wildling "foo#"
```

```dart
import 'package:wildling/wildling.dart';

final wildling = Wildling(['foo#']);
var value = wildling.next();
while (value != false) {
  print(value);
  value = wildling.next();
}
```

See language READMEs for patterns, CLI options, and templates.
Shared CLI contracts (help text, `--check` format): [docs/cli.md](docs/cli.md).

## Build & test

Language identifiers live in [`languages.txt`](languages.txt). Every
`*/build.sh` uses Docker.

```bash
./build.sh              # build every language (Docker)
./build.sh powershell   # build one language
./test.sh               # test every language against tests/
./test.sh lua python    # test selected languages
./scripts/build-site.sh # documentation site → _site/
```

Shared CLI contracts (help text, `--check` format, out-of-range stderr + exit 1):
[docs/cli.md](docs/cli.md). Shared semver and registry publish waves:
[docs/publishing.md](docs/publishing.md).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Security reports: [SECURITY.md](SECURITY.md).

Architecture and stack notes: [PLAN.md](PLAN.md).

## Install notes

All ports share one version in [`VERSION`](VERSION). Clone and build with
`./build.sh <language>`, or use a registry once that wave is live (see
[docs/publishing.md](docs/publishing.md)). **npm is not used** — JavaScript stays
`private`; install via git or the [Pages sandbox](https://dotmonk.github.io/wildling/sandbox.html).

## License

MIT — see [LICENSE](LICENSE).
