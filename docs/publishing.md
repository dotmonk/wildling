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

Never hand-edit per-language version constants. CI runs `./scripts/sync-version.sh --check`.

## Git tags

After syncing and pushing the version commit:

| Tag | Purpose |
|-----|---------|
| `vX.Y.Z` | Canonical release tag (GitHub Release, monorepo consumers, mirror sync) |
| `go/vX.Y.Z` | Go module tag for `github.com/dotmonk/wildling/go/v2` (subdirectory module) |

Example:

```bash
VERSION=$(tr -d '[:space:]' < VERSION)
git tag -a "v${VERSION}" -m "wildling ${VERSION}"
git tag -a "go/v${VERSION}" -m "wildling go module ${VERSION}"
git push origin "v${VERSION}" "go/v${VERSION}"
```

Create a GitHub Release from `vX.Y.Z`. [`.github/workflows/release.yml`](../.github/workflows/release.yml)
syncs ecosystem mirrors and publishes artifacts.

## Release notes template

```markdown
## wildling X.Y.Z

### Highlights
- …

### Install
See language READMEs (`javascript/`, `python/`, `go/`, …).

### Tags
- `vX.Y.Z`
- `go/vX.Y.Z`
```

## Publish channels

| Channel | Languages | Mechanism |
|---------|-----------|-----------|
| **Ecosystem mirrors** | PHP, Swift | CI → `wildling-php`, `wildling-swift` |
| **Artifact CI** | Python, Rust, Java, C#, Ruby, Dart, npm, … | Build in `lang/` → upload to registry |
| **Monorepo git tags** | Go, Zig, git URL installs | Tags on `wildling` (+ `go/vX.Y.Z` for `…/go/v2`) |

See **[ecosystem-repos.md](ecosystem-repos.md)** for mirror setup.

### Registry waves (artifact uploads)

| Wave | Registries |
|------|------------|
| 2 | PyPI, crates.io, NuGet, RubyGems, pub.dev |
| 3 | Hex.pm, LuaRocks, PowerShell Gallery |
| 4 | Maven Central (Java, then Kotlin/Scala/Groovy) |
| 5 | CPAN, Hackage, R-universe, Alire, fpm |
| 6 | C/C++ via GitHub Releases (+ optional vcpkg) |

Configure trusted publishers (or secrets), then publish a GitHub Release.

## Install

Each `<language>/README.md` documents registry packages, git dependencies, and clone-and-build steps.
