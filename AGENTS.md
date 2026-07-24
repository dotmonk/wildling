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
| `docs/template.schema.json`, `docs/template.example.json` | `--template` JSON (docs-only) |
| `docs/publishing.md` | Versioning and releases |
| `docs/ecosystem-repos.md` | PHP/Swift mirror setup |
| `docs/snippets/example.md` | Shared pattern example for READMEs + Pages |
| `site/lang-meta.json` | Per-language registry / docs links |
| `site/cookbook.html` | Short pattern recipes (GitHub Pages) |
| `<language>/README.md` | Install, git dependencies, library usage |

Do not add `docs/README.md` or a central git-install index. Prefer extending
`scripts/lang-preamble.py` / `build-site.sh` over adding Hugo or another site framework.

## Ecosystem mirrors

Only PHP and Swift need separate git repositories (Packagist and SwiftPM expect metadata at repo root). See `docs/ecosystem-repos.md`.

JavaScript publishes to npm from `javascript/` in CI (`npm publish --access public`).

## Releases

Version in root `VERSION`; sync with `scripts/sync-version.sh`.
Push to `main` after bumping `VERSION`: when Test + publish-artifact smoke pass,
`scripts/create-github-release.sh` creates `vX.Y.Z`, `go/vX.Y.Z`, and a GitHub Release
(skipped if the tag already exists). The same workflow then **dispatches**
`release.yml` (`gh workflow run`, not `workflow_call`) to publish
mirrors/registries — a `GITHUB_TOKEN` release event cannot start another
workflow, and reusable `workflow_call` from `test.yml` breaks OIDC trusted
publishers (JWT workflow claim would be `test.yml`).

Go module path for major ≥ 2 is `github.com/dotmonk/wildling/go/v2`.

Publish-artifact smoke (no upload): `./test.sh --publish-artifacts` → `scripts/smoke-publish-artifacts.sh`.
