# Ecosystem mirror repos

Packagist and SwiftPM expect package metadata at the git repository root. This
monorepo keeps each language in a subdirectory, so CI mirrors those trees into
dedicated repositories on each GitHub Release.

## Mirror repos

| Ecosystem repo | Source | Consumers |
|----------------|--------|-----------|
| [`dotmonk/wildling-php`](https://github.com/dotmonk/wildling-php) | `php/` | Packagist, Composer |
| [`dotmonk/wildling-swift`](https://github.com/dotmonk/wildling-swift) | `swift/` | SwiftPM (git) |

JavaScript, Python, Rust, and other ports publish from their subdirectories in
CI — no mirror repository. npm install from git:
`git+https://github.com/dotmonk/wildling.git#vX.Y.Z:javascript` (see
[`javascript/README.md`](../javascript/README.md)).

## One-time setup

1. Create empty GitHub repositories:
   - `dotmonk/wildling-php`
   - `dotmonk/wildling-swift`

2. Fine-grained PAT(s) with **Contents: Write** on each mirror.

3. Secrets on **`dotmonk/wildling`**:

   | Secret | Purpose |
   |--------|---------|
   | `PHP_MIRROR_TOKEN` | Push `wildling-php` |
   | `SWIFT_MIRROR_TOKEN` | Push `wildling-swift` |
   | `NPM_TOKEN` | Optional; npm publish from `javascript/` |

   Copy [`scripts/ecosystem-repos.example.env`](../scripts/ecosystem-repos.example.env) for local mirror runs.

4. Register consumers:
   - Packagist: `https://github.com/dotmonk/wildling-php`
   - SwiftPM: `https://github.com/dotmonk/wildling-swift.git`
   - npm: package `wildling` from monorepo CI

## Release flow

On **GitHub Release** (`vX.Y.Z`), [`.github/workflows/release.yml`](../.github/workflows/release.yml):

1. Mirror `php/` and `swift/` (when tokens are set)
2. Publish npm from `javascript/`
3. Publish artifacts (PyPI, crates.io, NuGet, …)

Manual mirror re-run: Actions → Release → Run workflow → set `tag` to `v2.0.0`.

```bash
source scripts/ecosystem-repos.env
./scripts/mirror-all-ecosystem.sh v2.0.0
```

| Script | Mirror |
|--------|--------|
| [`mirror-php-packagist.sh`](../scripts/mirror-php-packagist.sh) | php |
| [`mirror-swift-spm.sh`](../scripts/mirror-swift-spm.sh) | swift |

Shared push logic: [`mirror-ecosystem-lib.sh`](../scripts/mirror-ecosystem-lib.sh).  
Swift `Package.swift` template: [`scripts/templates/Package.swift`](../scripts/templates/Package.swift).
