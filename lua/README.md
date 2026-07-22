# wildling (Lua)

Lua library and CLI for pattern-based string generation. **Zero third-party dependencies** (pure Lua 5.4 stdlib — hand-rolled JSON). Requires Lua 5.4+.

## Install

From this repository:

```bash
cd lua
./build.sh
./bin/wildling "foo#"
```

**Git** (from monorepo root after clone):

```bash
git clone --branch v2.0.0 --depth 1 https://github.com/dotmonk/wildling.git
cd wildling
luarocks make lua/wildling.rockspec
```

**Registry:** `luarocks install wildling`

```lua
package.path = "./lib/?.lua;" .. "./lib/?/init.lua;" .. package.path
local wildling = require("wildling")

local w = wildling.create({ "foo#" })
local value = w:next()
while value ~= false do
    print(value)
    value = w:next()
end
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
./build.sh   # Docker (python:3.13-alpine + lua5.4): copy help.txt + luac -p syntax check
```

Project tests live in `../tests/` and are run with `../test.sh`.
