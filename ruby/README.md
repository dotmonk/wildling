# wildling (Ruby)

Ruby library and CLI for pattern-based string generation. **Zero third-party gems** (stdlib only, including `json`). Requires Ruby 3.0+.

## Install

From this repository:

```bash
cd ruby
./build.sh
./bin/wildling "foo#"
```

**Git (Bundler):**

```ruby
gem "wildling", git: "https://github.com/dotmonk/wildling.git", tag: "v2.0.0", glob: "ruby/wildling.gemspec"
```

**Registry:** `gem install wildling`

```ruby
require_relative "lib/wildling"

wildling = Wildling.create(["foo#"])
value = wildling.next
while value != false
  puts value
  value = wildling.next
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
./build.sh   # Docker (ruby:3.3-alpine): copy help.txt + syntax-check
```

Project tests live in `../tests/` and are run with `../test.sh`.
