# wildling (Groovy)

Groovy library and CLI for pattern-based string generation. **Zero third-party dependencies** (Groovy/Java stdlib only — hand-rolled JSON parser). Requires Groovy 4+ / JVM 17+.

## Install

From this repository:

```bash
cd groovy
./build.sh
./bin/wildling "foo#"
```

```groovy
import wildling.Wildling

def w = Wildling.createWildling(["foo#"])
def value = w.next()
while (value != false) {
    println value
    value = w.next()
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
./build.sh   # Docker (eclipse-temurin:21-jdk-jammy + Apache Groovy): copy help.txt + groovyc
```

Project tests live in `../tests/` and are run with `../test.sh`.
