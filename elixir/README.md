# wildling (Elixir)

Elixir library and CLI for pattern-based string generation. **Zero Hex dependencies** (Elixir/Erlang stdlib only — hand-rolled JSON parser). Requires Elixir 1.14+ / OTP 25+.

## Install

From this repository:

```bash
cd elixir
./build.sh
./bin/wildling "foo#"
```

**Git (`mix.exs`):**

```elixir
{:wildling, git: "https://github.com/dotmonk/wildling.git", tag: "v2.0.0", path: "elixir"}
```

**Registry:** `{:wildling, "~> 2.0"}` on Hex

```elixir
w = Wildling.create(["foo#"])
value = Wildling.next(w)
Stream.unfold(value, fn
  false -> nil
  v -> {v, Wildling.next(w)}
end)
|> Enum.each(&IO.puts/1)
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
./build.sh   # Docker (gcc:14-bookworm + apt elixir): cache .elixir, copy help.txt, elixirc
```

Project tests live in `../tests/` and are run with `../test.sh`.
