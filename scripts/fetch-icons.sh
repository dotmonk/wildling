#!/bin/sh
# Vendor language icons into site/assets/icons/ from Simple Icons (CC0 1.0).
# https://github.com/simple-icons/simple-icons
#
# Icons are single-path glyphs (black). The site colors them via CSS mask +
# currentColor so they stay visible on the dark theme and turn lime on hover.
set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/site/assets/icons"
# Prefer a release that includes csharp / powershell / visualbasic.
# Ada is fetched from develop (added later).
SI_TAG="11.14.0"
SI_BASE="https://cdn.jsdelivr.net/npm/simple-icons@${SI_TAG}/icons"
SI_ADA="https://raw.githubusercontent.com/simple-icons/simple-icons/develop/icons/ada.svg"

mkdir -p "$OUT"

fetch() {
    lang="$1"
    slug="$2"
    url="$3"
    dest="$OUT/${lang}.svg"
    echo "fetch $lang ← $slug"
    curl -fsSL -o "$dest" "$url"
    if ! grep -q '<svg' "$dest"; then
        echo "not an SVG: $dest" >&2
        exit 1
    fi
    # Light fill + evenodd so cutout-style icons (square + glyph) aren't solid boxes.
    python3 - "$dest" <<'PY'
from pathlib import Path
import re
import sys
p = Path(sys.argv[1])
text = p.read_text(encoding="utf-8")
text = re.sub(r"<title>[^<]*</title>", "", text)
if re.search(r"<svg\b[^>]*\sfill=", text):
    text = re.sub(r'(<svg\b[^>]*?)\sfill="[^"]*"', r'\1 fill="#e8f0ea"', text, count=1)
else:
    text = re.sub(r"<svg\b", '<svg fill="#e8f0ea"', text, count=1)
if "fill-rule=" not in text:
    text = re.sub(r"<svg\b", '<svg fill-rule="evenodd"', text, count=1)
p.write_text(text, encoding="utf-8")
PY
}

# wildling id → simple-icons slug
fetch javascript  javascript   "$SI_BASE/javascript.svg"
fetch python      python       "$SI_BASE/python.svg"
fetch java        openjdk      "$SI_BASE/openjdk.svg"
fetch csharp      csharp       "$SI_BASE/csharp.svg"
fetch visualbasic visualbasic  "$SI_BASE/visualbasic.svg"
fetch cpp         cplusplus    "$SI_BASE/cplusplus.svg"
fetch php         php          "$SI_BASE/php.svg"
fetch c           c            "$SI_BASE/c.svg"
fetch go          go           "$SI_BASE/go.svg"
fetch rust        rust         "$SI_BASE/rust.svg"
fetch kotlin      kotlin       "$SI_BASE/kotlin.svg"
fetch ruby        ruby         "$SI_BASE/ruby.svg"
fetch swift       swift        "$SI_BASE/swift.svg"
fetch scala       scala        "$SI_BASE/scala.svg"
fetch dart        dart         "$SI_BASE/dart.svg"
fetch posix-shell gnubash      "$SI_BASE/gnubash.svg"
fetch powershell  powershell   "$SI_BASE/powershell.svg"
fetch lua         lua          "$SI_BASE/lua.svg"
fetch assembly    webassembly  "$SI_BASE/webassembly.svg"
fetch r           r            "$SI_BASE/r.svg"
fetch groovy      apachegroovy "$SI_BASE/apachegroovy.svg"
fetch perl        perl         "$SI_BASE/perl.svg"
fetch elixir      elixir       "$SI_BASE/elixir.svg"
fetch pascal      delphi       "$SI_BASE/delphi.svg"
fetch zig         zig          "$SI_BASE/zig.svg"
fetch fortran     fortran      "$SI_BASE/fortran.svg"
fetch fsharp      fsharp       "$SI_BASE/fsharp.svg"
fetch haskell     haskell      "$SI_BASE/haskell.svg"
fetch ada         ada          "$SI_ADA"

cat > "$OUT/_fallback.svg" <<'EOF'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="#000">
  <path d="M12 2.5l1.1 4.2 4.3.2-3.3 2.8 1.1 4.2L12 11.7 8.8 13.9l1.1-4.2L6.6 6.9l4.3-.2L12 2.5z"/>
</svg>
EOF

cat > "$OUT/NOTICE.md" <<EOF
# Third-party icons

Language icons under this directory (except \`_fallback.svg\`) are vendored from
[Simple Icons](https://github.com/simple-icons/simple-icons) under **CC0 1.0**.

- Most icons: npm \`simple-icons@${SI_TAG}\`
- Ada: \`develop\` branch (\`icons/ada.svg\`)

\`_fallback.svg\` is original to wildling.

The site serves these glyphs as \`&lt;img&gt;\` with a light fill for the dark theme.
EOF

echo "Icons vendored into $OUT"
