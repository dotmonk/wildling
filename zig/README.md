# wildling (Zig)

Zig library and CLI for pattern-based string generation. **Zero third-party packages** (Zig standard library only; hand-rolled JSON for templates). Targets Zig 0.13+.

## Install

From this repository:

```bash
cd zig
./build.sh
./bin/wildling "foo#"
```

Produces `dist/wildling` (static-friendly ReleaseSafe binary) plus `dist/help.txt`.

**Path dependency** (after cloning the monorepo):

```zig
.wildling = .{ .path = "../wildling/zig" },
```

```zig
const wildling = @import("wildling");

var w = try wildling.Wildling.init(allocator, &.{"foo#"}, &dicts);
while (try w.next(allocator)) |value| {
    std.debug.print("{s}\n", .{value});
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
./build.sh   # Docker (gcc:14-bookworm): fetch Zig into .zig if needed, zig build → dist/wildling
```

Project tests live in `../tests/` and are run with `../test.sh`.
