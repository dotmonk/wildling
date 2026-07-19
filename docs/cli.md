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

When an index is outside `[0, count)`:

- Write **nothing** to stdout for that index (no value line).
- Write one line to **stderr**: `out of range: <index>` (decimal ASCII, no quotes).
- After all selects/ranges are processed, exit with status `1` if any index was
  out of range; otherwise `0`.

Do **not** print the word `false` (or `False` / `FALSE`) on stdout for this case.
That word can be a real generated combination, so it must not double as a
sentinel.

Library `get` / equivalent APIs may still return a **typed** false / `None` /
`nil` for out-of-range access; that is distinct from the string `"false"`.
