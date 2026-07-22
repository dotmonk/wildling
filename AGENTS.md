# Agent and maintainer notes

Internal conventions — not end-user documentation. Install instructions belong in each `<language>/README.md`.

## Monorepo root

Do not add ecosystem package manifests at the repository root (`composer.json`, `package.json`, `Package.swift`, `pyproject.toml`, `pubspec.yaml`, `Cargo.toml`, `go.mod`, `mix.exs`, `wildling.gemspec`, …). Each language lives in its own subdirectory.

CI runs `scripts/check-monorepo-root.sh` in the `version` job.

## Documentation layout

| Path | Purpose |
|------|---------|
| `README.md` | Project overview |
| `docs/cli.md`, `docs/help.txt` | Shared CLI contracts |
| `docs/publishing.md` | Versioning and releases |
| `docs/ecosystem-repos.md` | PHP/Swift mirror setup |
| `<language>/README.md` | Install, git dependencies, library usage |

Do not add `docs/README.md` or a central git-install index.

## Ecosystem mirrors

Only PHP and Swift need separate git repositories (Packagist and SwiftPM expect metadata at repo root). See `docs/ecosystem-repos.md`.

JavaScript publishes to npm from `javascript/` in CI. `javascript/package.json` is `private: true` in git; the release workflow sets `private: false` only when publishing.

## Releases

Version in root `VERSION`; sync with `scripts/sync-version.sh`. Tags: `vX.Y.Z` and `go/vX.Y.Z`.
Go module path for major ≥ 2 is `github.com/dotmonk/wildling/go/v2`. See `docs/publishing.md` and `.github/workflows/release.yml`.

Publish-artifact smoke (no upload): `./test.sh --publish-artifacts` → `scripts/smoke-publish-artifacts.sh`.
