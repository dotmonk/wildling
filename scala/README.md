# wildling (Scala)

Scala library and CLI for pattern-based string generation. **Zero third-party dependencies** (Scala/JVM standard library only; hand-rolled JSON for templates). Targets Scala 2.13+ / JVM 11+.

## Install

From this repository:

```bash
cd scala
./build.sh
./bin/wildling "foo#"
```

From a release tag:

```bash
git clone --branch v2.0.0 --depth 1 https://github.com/dotmonk/wildling.git
cd wildling
./build.sh scala
```


**Registry:** Maven Central (when published)

Produces `dist/wildling.jar` (includes `scala-library`). Requires a JRE to run, or Docker (the launcher falls back to Temurin if `java` is not on `PATH`).

```scala
val wildling = Wildling(Seq("foo#"))
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
./build.sh   # Docker (Temurin): fetch Scala if needed, scalac + fat jar → dist/wildling.jar
```

Project tests live in `../tests/` and are run with `../test.sh`.
