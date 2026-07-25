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
[`.github/workflows/release.yml`](../.github/workflows/release.yml). After Test
creates a GitHub Release, it **dispatches** that workflow (`gh workflow run`) so
OIDC trusted publishers (npm, PyPI, crates.io) see workflow filename
`release.yml`. Calling it as a reusable workflow from `test.yml` breaks those
publishers (JWT claims `test.yml`).

You can also run Actions → Release → Run workflow with `tag` set (e.g. `v2.0.3`),
or publish a GitHub Release manually (the `release` event also starts the same
workflow when the actor is not `GITHUB_TOKEN`).

**pub.dev:** OIDC only accepts runs whose GitHub ref is a **tag** (not `main`).
Release dispatches `publish-pub.yml` with `--ref vX.Y.Z`. To republish manually:
`gh workflow run publish-pub.yml --ref v2.0.3`.

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
| 5 | CPAN, R-universe |
| 6 | C/C++ via GitHub Releases (+ optional vcpkg) |

### Wave 5 secrets / one-time setup

| Job | Secret / var | Notes |
|-----|--------------|--------|
| CPAN | `CPAN_USER`, `CPAN_PASSWORD` | PAUSE id + password |
| R-universe | `RUNIVERSE_TOKEN` (optional); vars `RUNIVERSE_OWNER` (default `dotmonk`), `RUNIVERSE_REPO` (default `OWNER/OWNER.r-universe.dev`) | Builds `r/` always; token upserts `packages.json` on the registry repo (e.g. [dotmonk/dotmonk.r-universe.dev](https://github.com/dotmonk/dotmonk.r-universe.dev)). Also install the [R-universe GitHub App](https://docs.r-universe.dev/publish/set-up.html). |

Ada, Fortran, and Haskell have no package registries in this project — install from git (see their READMEs). The Perl distribution on CPAN is **`Wildling`** (`cpanm Wildling`).

### Wave 6 — C / C++ (GitHub Releases)

No registry account required. The Release workflow builds Linux x86_64 CLI binaries and source trees, then uploads:

| Asset | Contents |
|-------|----------|
| `wildling-c-X.Y.Z-linux-x86_64.tar.gz` | `wildling` CLI + `help.txt` |
| `wildling-cpp-X.Y.Z-linux-x86_64.tar.gz` | same for C++ |
| `wildling-c-X.Y.Z-src.tar.gz` | `src/` + `CMakeLists.txt` |
| `wildling-cpp-X.Y.Z-src.tar.gz` | same for C++ |

Consumers can also use CMake `FetchContent` with `SOURCE_SUBDIR` `c` or `cpp` (see language READMEs). **vcpkg** is deferred until these assets are stable.

Configure trusted publishers (or secrets), then bump `VERSION` and push to `main`.

## Post-release smoke

After packages propagate, CI verifies **consumer** installs (not in-repo `./build.sh`):

```bash
./post-release-smoke-test.sh              # all languages in languages.txt
WILDLING_SMOKE_TAG=v2.0.6 ./post-release-smoke-test.sh javascript python
```

Each language owns `<language>/post-release-smoke.sh` (same idea as `build.sh`).
Shared helpers live in [`scripts/post-release-smoke-lib.sh`](../scripts/post-release-smoke-lib.sh);
the root harness is [`scripts/post-release-smoke.sh`](../scripts/post-release-smoke.sh).

Workflow [`.github/workflows/post-release-smoke.yml`](../.github/workflows/post-release-smoke.yml)
runs on an hourly cron (`:10`). A gate
([`scripts/should-run-post-release-smoke.sh`](../scripts/should-run-post-release-smoke.sh))
starts the matrix when:

| Condition | Reason |
|-----------|--------|
| Latest GitHub Release age is in `[24h10m, 25h10m)` | `post-release` |
| Latest release age ≥ 48h and UTC hour is 3 (03:10 cron) | `daily` |

Manual runs: Actions → Post-release smoke → Run workflow (`force` defaults on).

## Install

Each `<language>/README.md` documents registry packages, git dependencies, and
clone-and-build steps. Prefer those READMEs over inventing install commands:
several ecosystems have sharp edges (Cargo forbids combining `git`+`path`, NuGet
`PackAsTool` packages are CLI-only, Composer path repos need a version pin, npm
`#tag:subdir` for this monorepo is unreliable, LuaRocks ≤2.0.6 rocks need a
make workaround). Post-release smoke (`./post-release-smoke-test.sh`) exercises
the documented consumer paths.
