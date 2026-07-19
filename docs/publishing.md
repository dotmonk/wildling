# Publishing and versioning

All language ports share one semver from the root [`VERSION`](../VERSION) file
(plain `MAJOR.MINOR.PATCH`, no `v` prefix).

## Bumping the version

```bash
./release.sh          # bumps patch in VERSION, syncs all ports, builds
# or:
echo 1.2.0 > VERSION
./scripts/sync-version.sh
```

Never hand-edit per-language version constants. CI runs
`./scripts/sync-version.sh --check` on every push/PR.

## Git tags

After syncing and pushing the version commit:

| Tag | Purpose |
|-----|---------|
| `vX.Y.Z` | Canonical release tag (GitHub Release, Packagist, SwiftPM, Zig, PyPI, …) |
| `go/vX.Y.Z` | Go module tag for `github.com/dotmonk/wildling/go` (subdirectory module) |

Example:

```bash
VERSION=$(tr -d '[:space:]' < VERSION)
git tag -a "v${VERSION}" -m "wildling ${VERSION}"
git tag -a "go/v${VERSION}" -m "wildling go module ${VERSION}"
git push origin "v${VERSION}" "go/v${VERSION}"
```

Create a GitHub Release from `vX.Y.Z` (UI or `gh release create`). The
[`.github/workflows/release.yml`](../.github/workflows/release.yml) workflow
publishes to configured registries when that release is published.

## Release notes template

```markdown
## wildling X.Y.Z

### Highlights
- …

### Install
See [docs/publishing.md](https://github.com/dotmonk/wildling/blob/main/docs/publishing.md)
and language READMEs. Shared CLI contract: [docs/cli.md](https://github.com/dotmonk/wildling/blob/main/docs/cli.md).

### Tags
- `vX.Y.Z`
- `go/vX.Y.Z`
```

## Registry waves

| Wave | Registries | GitHub integration |
|------|------------|--------------------|
| 0 | GitHub Releases only | Tag + Release |
| 1 | Go proxy, Packagist, SwiftPM (git), Zig (git) | Tags / Packagist GitHub hook |
| 2 | PyPI, crates.io, NuGet, RubyGems, pub.dev | OIDC trusted publishing |
| 3 | Hex.pm, LuaRocks, PowerShell Gallery | API keys / CI secrets |
| 4 | Maven Central (Java, then Kotlin/Scala/Groovy) | Sonatype + CI |
| 5 | CPAN, Hackage, R-universe, Alire, fpm | Accounts / git |
| 6 | C/C++ via Releases (+ optional vcpkg later) | Releases |

**Not published:** npm (JavaScript stays `private: true`; install from git or use the
Pages sandbox). Prefer R-universe over CRAN initially.

### Wave 1 — tag consumers

- **Go:** `go get github.com/dotmonk/wildling/go@vX.Y.Z` (requires `go/vX.Y.Z` tag).
- **PHP:** Packagist package `dotmonk/wildling`. Submit
  `https://github.com/dotmonk/wildling` only (not a `/php` URL). Packagist
  reads the **root** [`composer.json`](../composer.json), which autoloads
  `php/src/`. Versions come from git tags `vX.Y.Z`.
- **Swift:** SwiftPM package at repo root (`Package.swift`) from tag `vX.Y.Z`.
- **Zig:** dependency on the git tag via `build.zig.zon` / `zig fetch`.

### Wave 2+ — CI publish

Configure trusted publishers (or secrets) for each registry, then publish a
GitHub Release. Jobs in `release.yml` are no-ops until credentials exist.

## Install from git (any language)

```bash
git clone https://github.com/dotmonk/wildling.git
cd wildling
./build.sh <language>
./test.sh <language>
```
