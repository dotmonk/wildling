# wildling (C++)

C++ library and CLI for pattern-based string generation. **Zero third-party dependencies** (C++17 standard library only). Includes a minimal JSON parser for `--template`.

## Install

From this repository:

```bash
cd cpp
./build.sh
./bin/wildling "foo#"
```

Produces `dist/wildling`. Link against the sources under `src/` (except `cli.cpp`) to use as a library:

```cpp
#include "wildling.hpp"

wildling::Dictionaries dictionaries;
wildling::Wildling w({"foo#"}, dictionaries);
auto value = w.next();
while (value.has_value()) {
    std::cout << *value << '\n';
    value = w.next();
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
./build.sh   # Docker (gcc:14-bookworm): g++ -std=c++17 → dist/wildling
```

Project tests live in `../tests/` and are run with `../test.sh`.
