# Publishing and versioning

All language ports share one semver from the root [`VERSION`](../VERSION) file
(plain `MAJOR.MINOR.PATCH`, no `v` prefix).

## Bumping and releasing

```bash
./release.sh          # bumps patch in VERSION, syncs all ports, builds
# or:
echo 1.2.0 > VERSION
./scripts/sync-version.sh
```

Commit, push to `main`, and wait for CI. When tests and publish-artifact smoke
pass, CI creates:

| Tag | Purpose |
|-----|---------|
| `vX.Y.Z` | Canonical release tag + GitHub Release |
| `go/vX.Y.Z` | Go module tag for `github.com/dotmonk/wildling/go/v2` |

If `vX.Y.Z` already exists, CI skips creating a new release.

Publishing mirrors and registry packages runs from
[`.github/workflows/release.yml`](../.github/workflows/release.yml), invoked
directly after a new release is created (and also via Actions → Release → Run
workflow, or a manually published GitHub Release).

Never hand-edit per-language version constants. CI runs `./scripts/sync-version.sh --check`.

## Release notes

GitHub generates notes from commits since the previous tag. Optional body:

```markdown
## wildling X.Y.Z

### Highlights
- …

### Install
See language READMEs (`javascript/`, `python/`, `go/`, …).
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

Configure trusted publishers (or secrets), then bump `VERSION` and push to `main`.

## Install

Each `<language>/README.md` documents registry packages, git dependencies, and clone-and-build steps.
