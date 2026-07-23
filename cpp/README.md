# wildling

C++ library and CLI for pattern-based string generation. **Zero third-party dependencies** (C++17 standard library only). Includes a minimal JSON parser for `--template`.

<!-- wildling:preamble -->
**Docs:** [Website](https://dotmonk.github.io/wildling/) · [Sandbox](https://dotmonk.github.io/wildling/sandbox.html) · [Syntax](https://dotmonk.github.io/wildling/syntax.html) · [Source](https://github.com/dotmonk/wildling/tree/main/cpp)

## Example

```text
http://${'dev,stage,prod'}\-${'api,web'}#{0-2}.example.${'com,net,org'}/@.html
```

(The `\-` is a literal hyphen; bare `-` would mean “one letter or digit”. `@` is one lowercase letter.)

That builds **URL-shaped** candidates: scheme `http://`, then environment × service × optional digits × TLD, then a one-letter path page. Three environments, two services, zero–two digits (`''`, `0`–`9`, `00`–`99`), three TLDs, and `a`–`z` → **51948** strings — the kind of list you generate for fuzzing links or probing staging hosts, not type out.

A few of them:

- `http://dev-api.example.com/a.html` / `http://stage-web.example.com/z.html`
- `http://dev-api0.example.net/a.html` / `http://prod-web9.example.org/m.html`
- `http://dev-api00.example.com/a.html` / `http://prod-web99.example.org/z.html`

Named dictionaries (`%{'hosts'}`) work the same way when the word lists live in files.

Try it in the [sandbox](https://dotmonk.github.io/wildling/sandbox.html?pattern=http%3A%2F%2F%24%7B%27dev%2Cstage%2Cprod%27%7D%5C-%24%7B%27api%2Cweb%27%7D%23%7B0-2%7D.example.%24%7B%27com%2Cnet%2Corg%27%7D%2F%40.html), or see [pattern syntax](https://dotmonk.github.io/wildling/syntax.html) for length ranges, dictionaries, and escapes.
<!-- /wildling:preamble -->

## Install

From this repository:

```bash
cd cpp
./build.sh
./bin/wildling "Year 19##"
```

From a release tag:

```bash
git clone --branch v2.0.2 --depth 1 https://github.com/dotmonk/wildling.git
cd wildling
./build.sh cpp
```

**GitHub Release assets** (Linux x86_64 CLI + source tarballs) are attached to each [`vX.Y.Z` release](https://github.com/dotmonk/wildling/releases).

**CMake** (library + CLI), including `FetchContent` from the monorepo:

```cmake
include(FetchContent)
FetchContent_Declare(
  wildling
  GIT_REPOSITORY https://github.com/dotmonk/wildling.git
  GIT_TAG v2.0.2
  SOURCE_SUBDIR cpp
)
FetchContent_MakeAvailable(wildling)
target_link_libraries(myapp PRIVATE wildling)
```

Produces `dist/wildling`. Link against the sources under `src/` (except `cli.cpp`) to use as a library:

```cpp
#include "wildling.hpp"

wildling::Dictionaries dictionaries;
wildling::Wildling w({"Year 19##"}, dictionaries);
auto value = w.next();
while (value.has_value()) {
    std::cout << *value << '\n';
    value = w.next();
}
```

## CLI

```bash
./bin/wildling "Year 19##"
./bin/wildling --dictionary planets:../dictionaries/planets.txt "%{'planets'}"
./bin/wildling --template ./config.json
```

Help text and `--check` output follow [`docs/cli.md`](../docs/cli.md) / [`docs/help.txt`](../docs/help.txt).

## Build

```bash
./build.sh   # Docker (gcc:14-bookworm): g++ -std=c++17 → dist/wildling
```

Project tests live in `../tests/` and are run with `../test.sh`.
