# CLI contracts

Shared text and output formats used by every language implementation.

## Help

Source of truth: [`help.txt`](help.txt)

Each language CLI should print this file for `--help` / `-h` (copy into the
build artifact if the binary is distributed outside the repo).

## `--check` output

Stable, language-neutral lines (UTF-8, `\n` newlines):

```
patterns: <pattern> ...
dictionaries: <name> ...
select: <index> ...
range: <start-end> ...
total: <count>
generator: <pattern> <count>
generator: <pattern> <count>
...
```

Rules:

- Fields appear in this order.
- Empty lists print the key and a trailing space is omitted (`dictionaries:` with nothing after the colon).
- Multiple values on one line are separated by a single space.
- One `generator:` line per pattern, in pattern order.
- No extra blank lines.

## Out-of-range `--select` / `--range`

When an index is outside `[0, count)`, print the lowercase ASCII word `false`
(one line, no quotes). Do **not** print language-localized booleans such as
`False` or `FALSE`.
