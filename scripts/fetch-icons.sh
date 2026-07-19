#!/bin/sh
# Vendor language icons into site/assets/icons/
# Primary: Devicons (MIT) — https://github.com/devicons/devicon
# Ada only: Simple Icons (CC0) — https://github.com/simple-icons/simple-icons
set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/site/assets/icons"
# Pinned Devicon commit (update intentionally when refreshing icons).
DEVICON_REF="7330accdbc47"
DEVICON_BASE="https://cdn.jsdelivr.net/gh/devicons/devicon@${DEVICON_REF}/icons"
# Simple Icons commit for Ada (not in Devicon).
SIMPLE_ICONS_REF="develop"
SIMPLE_ICONS_BASE="https://raw.githubusercontent.com/simple-icons/simple-icons/${SIMPLE_ICONS_REF}/icons"

mkdir -p "$OUT"

fetch() {
    lang="$1"
    url="$2"
    dest="$OUT/${lang}.svg"
    echo "fetch $lang"
    curl -fsSL -o "$dest" "$url"
    # Strip XML titles that some screen readers duplicate; keep markup otherwise.
    # Ensure files are non-empty SVGs.
    if ! grep -q '<svg' "$dest"; then
        echo "not an SVG: $dest" >&2
        exit 1
    fi
}

# wildling id → Devicon path under icons/
fetch javascript   "$DEVICON_BASE/javascript/javascript-original.svg"
fetch python       "$DEVICON_BASE/python/python-original.svg"
fetch java         "$DEVICON_BASE/java/java-original.svg"
fetch csharp       "$DEVICON_BASE/csharp/csharp-original.svg"
fetch visualbasic  "$DEVICON_BASE/visualbasic/visualbasic-original.svg"
fetch cpp          "$DEVICON_BASE/cplusplus/cplusplus-original.svg"
fetch php          "$DEVICON_BASE/php/php-original.svg"
fetch c            "$DEVICON_BASE/c/c-original.svg"
fetch go           "$DEVICON_BASE/go/go-original.svg"
fetch rust         "$DEVICON_BASE/rust/rust-original.svg"
fetch kotlin       "$DEVICON_BASE/kotlin/kotlin-original.svg"
fetch ruby         "$DEVICON_BASE/ruby/ruby-original.svg"
fetch swift        "$DEVICON_BASE/swift/swift-original.svg"
fetch scala        "$DEVICON_BASE/scala/scala-original.svg"
fetch dart         "$DEVICON_BASE/dart/dart-original.svg"
fetch posix-shell  "$DEVICON_BASE/bash/bash-original.svg"
fetch powershell   "$DEVICON_BASE/powershell/powershell-original.svg"
fetch lua          "$DEVICON_BASE/lua/lua-original.svg"
fetch assembly     "$DEVICON_BASE/embeddedc/embeddedc-original.svg"
fetch r            "$DEVICON_BASE/r/r-original.svg"
fetch groovy       "$DEVICON_BASE/groovy/groovy-original.svg"
fetch perl         "$DEVICON_BASE/perl/perl-original.svg"
fetch elixir       "$DEVICON_BASE/elixir/elixir-original.svg"
fetch pascal       "$DEVICON_BASE/delphi/delphi-original.svg"
fetch zig          "$DEVICON_BASE/zig/zig-original.svg"
fetch fortran      "$DEVICON_BASE/fortran/fortran-original.svg"
fetch fsharp       "$DEVICON_BASE/fsharp/fsharp-original.svg"
fetch haskell      "$DEVICON_BASE/haskell/haskell-original.svg"

# Ada: Simple Icons (CC0)
fetch ada          "$SIMPLE_ICONS_BASE/ada.svg"

# Monochrome icons (black paths) are invisible on the dark site — tint them.
python3 - "$OUT" <<'PY'
from pathlib import Path
import re
import sys

icons = Path(sys.argv[1])
for p in icons.glob("*.svg"):
    if p.name.startswith("_"):
        continue
    text = p.read_text(encoding="utf-8")
    if re.search(r"#[0-9a-fA-F]{6}", text):
        continue
    if re.search(r"<svg\b[^>]*\sfill=", text):
        text = re.sub(
            r'(<svg\b[^>]*?)\sfill="[^"]*"',
            r'\1 fill="#e8f0ea"',
            text,
            count=1,
        )
    else:
        text = re.sub(r"<svg\b", '<svg fill="#e8f0ea"', text, count=1)
    p.write_text(text, encoding="utf-8")
    print(f"tinted mono {p.name}")
PY

# Fallback mark (original, not third-party)
cat > "$OUT/_fallback.svg" <<'EOF'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="#c8f542">
  <path d="M12 2.5l1.1 4.2 4.3.2-3.3 2.8 1.1 4.2L12 11.7 8.8 13.9l1.1-4.2L6.6 6.9l4.3-.2L12 2.5z"/>
</svg>
EOF

cat > "$OUT/NOTICE.md" <<EOF
# Third-party icons

Language icons under this directory (except \`_fallback.svg\`) are vendored from:

## Devicons
- Project: https://github.com/devicons/devicon
- License: MIT
- Pin: commit \`${DEVICON_REF}\`
- Used for all language marks except Ada

## Simple Icons (Ada only)
- Project: https://github.com/simple-icons/simple-icons
- License: CC0 1.0
- Source: \`${SIMPLE_ICONS_REF}\` branch \`icons/ada.svg\`

\`_fallback.svg\` is original to wildling.
EOF

echo "Icons vendored into $OUT"
