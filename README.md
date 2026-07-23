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
  <a href="https://dotmonk.github.io/wildling/cookbook.html">Cookbook</a>
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
- [Cookbook](https://dotmonk.github.io/wildling/cookbook.html)

Build the site locally with `./scripts/build-site.sh` (output in `_site/`). In the repo **Settings → Pages**, set the source to **GitHub Actions**.

## Install

Pick a published channel when you can; otherwise clone and build that language directory.

| Channel | Install |
|---------|---------|
| **npm** | `npm install wildling` |
| **PyPI** | `pip install wildling` |
| **crates.io** | `cargo install wildling` |
| **Go** | `go get github.com/dotmonk/wildling/go/v2@latest` |
| **NuGet** | `dotnet tool install -g DotMonk.Wildling` |

More registries (Maven, Packagist, RubyGems, pub.dev, Hex, LuaRocks, …) and git-only ports are listed on the [website language wall](https://dotmonk.github.io/wildling/#languages) and in each `<language>/README.md`.

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
./bin/wildling "Year 19##"
```

```
Year 1900
Year 1910
…
Year 1999
```

As a library (from this repo):

```js
const createWildling = require("./javascript/dist/index.js").default;

const wildling = createWildling({
  patterns: ["Year 19##"],
  dictionaries: {},
});

let value;
while ((value = wildling.next()) !== false) {
  console.log(value);
}
```

## Quick start (Python)

```bash
cd python && ./build.sh
./bin/wildling "Year 19##"
```

```python
from wildling import create_wildling

wildling = create_wildling(patterns=["Year 19##"])
value = wildling.next()
while value is not False:
    print(value)
    value = wildling.next()
```

## Quick start (Java)

```bash
cd java && ./build.sh
./bin/wildling "Year 19##"
```

```java
import wildling.Wildling;
import java.util.List;

Wildling wildling = Wildling.create(List.of("Year 19##"));
Object value = wildling.next();
while (!Boolean.FALSE.equals(value)) {
    System.out.println(value);
    value = wildling.next();
}
```

## Quick start (C#)

```bash
cd csharp && ./build.sh
./bin/wildling "Year 19##"
```

```csharp
using WildlingLib;

var wildling = Wildling.Create(new[] { "Year 19##" });
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
./bin/wildling "Year 19##"
```

```vb
Imports WildlingLib

Dim wildling = Wildling.Create({"Year 19##"})
Dim value As Object = wildling.Next()
While Not (TypeOf value Is Boolean AndAlso Not CBool(value))
    Console.WriteLine(value)
    value = wildling.Next()
End While
```

## Quick start (C++)

```bash
cd cpp && ./build.sh
./bin/wildling "Year 19##"
```

```cpp
#include "wildling.hpp"
#include <iostream>

wildling::Dictionaries dictionaries;
wildling::Wildling w({"Year 19##"}, dictionaries);
auto value = w.next();
while (value.has_value()) {
    std::cout << *value << '\n';
    value = w.next();
}
```

## Quick start (PHP)

```bash
cd php && ./build.sh
./bin/wildling "Year 19##"
```

```php
<?php
require 'php/bootstrap.php';

use Wildling\Wildling;

$wildling = Wildling::create(['Year 19##']);
$value = $wildling->next();
while ($value !== false) {
    echo $value, "\n";
    $value = $wildling->next();
}
```

## Quick start (C)

```bash
cd c && ./build.sh
./bin/wildling "Year 19##"
```

## Quick start (Go)

```bash
cd go && ./build.sh
./bin/wildling "Year 19##"
```

```go
import "github.com/dotmonk/wildling/go/v2/wildling"

w := wildling.New([]string{"Year 19##"}, nil)
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
./bin/wildling "Year 19##"
```

```rust
use wildling::{Dictionaries, Wildling};

let dicts = Dictionaries::new();
let mut w = Wildling::new(&["Year 19##".to_string()], &dicts);
while let Some(value) = w.next() {
    println!("{value}");
}
```

## Quick start (Kotlin)

```bash
cd kotlin && ./build.sh
./bin/wildling "Year 19##"
```

```kotlin
import wildling.Wildling

val wildling = Wildling.create(listOf("Year 19##"))
var value = wildling.next()
while (value != false) {
    println(value)
    value = wildling.next()
}
```

## Quick start (Ruby)

```bash
cd ruby && ./build.sh
./bin/wildling "Year 19##"
```

```ruby
require_relative "lib/wildling"

wildling = Wildling.create(["Year 19##"])
value = wildling.next
while value != false
  puts value
  value = wildling.next
end
```

## Quick start (Swift)

```bash
cd swift && ./build.sh
./bin/wildling "Year 19##"
```

```swift
let wildling = Wildling(patterns: ["Year 19##"])
while let value = wildling.next() {
    print(value)
}
```

## Quick start (Scala)

```bash
cd scala && ./build.sh
./bin/wildling "Year 19##"
```

```scala
val wildling = Wildling(Seq("Year 19##"))
var value = wildling.next()
while (value != false) {
  println(value)
  value = wildling.next()
}
```

## Quick start (Dart)

```bash
cd dart && ./build.sh
./bin/wildling "Year 19##"
```

```dart
import 'package:wildling/wildling.dart';

final wildling = Wildling(['Year 19##']);
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
[docs/cli.md](docs/cli.md). Versioning and publishing: [docs/publishing.md](docs/publishing.md).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Security reports: [SECURITY.md](SECURITY.md).

Architecture and stack notes: [PLAN.md](PLAN.md).

## License

MIT — see [LICENSE](LICENSE).
