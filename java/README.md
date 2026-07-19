# wildling (Java)

Java library and CLI for pattern-based string generation. **Zero third-party dependencies** (JDK standard library only). Targets Java 11+.

## Install

From this repository:

```bash
cd java
./build.sh
./bin/wildling "foo#"
```

Produces `dist/wildling.jar`. Requires a JRE to run (`java -jar`), or Docker (the launcher falls back to the Temurin image if `java` is not on `PATH`).

As a library, add `dist/wildling.jar` to your classpath:

```java
import wildling.Wildling;
import java.util.List;
import java.util.Map;

Wildling wildling = Wildling.create(List.of("foo#"), Map.of());
Object value = wildling.next();
while (!Boolean.FALSE.equals(value)) {
    System.out.println(value);
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
./build.sh   # Docker (eclipse-temurin): javac + jar, embeds help.txt
```

Project tests live in `../tests/` and are run with `../test.sh`.
