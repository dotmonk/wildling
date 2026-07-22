# wildling (Kotlin)

Kotlin library and CLI for pattern-based string generation. **Zero third-party dependencies** (Kotlin/JVM standard library only; hand-rolled JSON for templates). Targets JVM 11+.

## Install

From this repository:

```bash
cd kotlin
./build.sh
./bin/wildling "foo#"
```

From a release tag:

```bash
git clone --branch v2.0.0 --depth 1 https://github.com/dotmonk/wildling.git
cd wildling
./build.sh kotlin
```


**Registry:** Maven Central (when published)

Produces `dist/wildling.jar`. Requires a JRE to run (`java -jar`), or Docker (the launcher falls back to the Temurin image if `java` is not on `PATH`).

As a library, add `dist/wildling.jar` to your classpath:

```kotlin
import wildling.Wildling

val wildling = Wildling.create(listOf("foo#"))
var value = wildling.next()
while (value != false) {
    println(value)
    value = wildling.next()
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
./build.sh   # Docker (Temurin): fetch kotlinc if needed, kotlinc + jar → dist/wildling.jar
```

Project tests live in `../tests/` and are run with `../test.sh`.
