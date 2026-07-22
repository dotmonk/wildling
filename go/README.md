# wildling (Go)

Go library and CLI for pattern-based string generation. **Zero third-party modules** (Go standard library only).

## Install

From this repository:

```bash
cd go
./build.sh
./bin/wildling "foo#"
```

**Module** (tags `vX.Y.Z` and `go/vX.Y.Z` on the monorepo — see [`docs/publishing.md`](../docs/publishing.md)):

```bash
go get github.com/dotmonk/wildling/go@v2.0.0
go install github.com/dotmonk/wildling/go/cmd/wildling@v2.0.0
```

As a library:

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

## CLI

```bash
./bin/wildling "foo#"
./bin/wildling --dictionary planets:../dictionaries/planets.txt "%{'planets'}"
./bin/wildling --template ./config.json
```

Help text and `--check` output follow [`docs/cli.md`](../docs/cli.md) / [`docs/help.txt`](../docs/help.txt).

## Build

```bash
./build.sh   # Docker (golang:1.22): go build → dist/wildling
```

Project tests live in `../tests/` and are run with `../test.sh`.
