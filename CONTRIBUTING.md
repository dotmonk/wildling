# Contributing

Thanks for interest in wildling. This repo is a multi-language implementation of
one pattern grammar and one CLI contract.

## Requirements

- Docker (every `*/build.sh` runs inside a container)
- A POSIX shell for root `./build.sh` / `./test.sh`
- Node.js 18+ only if you work on `javascript/` or the site

## Build and test

```bash
./build.sh javascript      # one language
./test.sh javascript

./build.sh                 # all languages in languages.txt
./test.sh
```

Fixtures live under `tests/`. Each case has `arguments.txt` and `expected.txt`.
CLI stdout must match exactly.

Shared contracts:

- [`docs/cli.md`](docs/cli.md) — `--check` format, out-of-range stderr + exit 1
- [`docs/help.txt`](docs/help.txt) — `--help` text (copied into build artifacts)

## Versioning

All languages share one semver in the root [`VERSION`](VERSION) file. Sync with
`./scripts/sync-version.sh` (also run by `./release.sh`). CI checks for drift.

Publishing: [`docs/publishing.md`](docs/publishing.md). Maintainer conventions: [`AGENTS.md`](AGENTS.md).

## Adding or changing a language

1. Keep **zero third-party runtime dependencies** outside that language’s stdlib
   (hand-roll template JSON unless the stdlib already includes JSON).
2. Provide `\<lang>/build.sh` (Docker), `\<lang>/bin/wildling`, and a README.
3. Add the id to [`languages.txt`](languages.txt) (popularity / status-table order).
4. Pass `./build.sh <lang> && ./test.sh <lang>` including the shared fixtures.
5. Update the root README status table and, if needed, `PLAN.md` stack notes.

## Website

```bash
./scripts/fetch-icons.sh   # vendor Simple Icons SVGs (optional refresh)
./scripts/build-site.sh    # writes _site/ (gitignored)
```

Sources: `site/`. Icon attribution: `site/assets/icons/NOTICE.md`. Deployed from
`.github/workflows/pages.yml` on `main`.

## Pull requests

- Prefer focused PRs (one language or one shared contract change).
- CI on PRs tests changed languages (always includes `javascript`). Changes under
  `tests/`, `docs/`, or root scripts trigger a broader matrix.
- Do not commit generated trees (`*/dist`, toolchains, `_site/`).
- Do not hand-edit per-language version strings; change [`VERSION`](VERSION) and
  run `./scripts/sync-version.sh`.

## Code of conduct

Be respectful. Hostile or abusive behavior is not welcome.
