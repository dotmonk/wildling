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

# Original assembly mark: circular badge with "x64" cutout (x86-64 NASM).
# Simple Icons has no NASM mark; its "webassembly" glyph is the wrong "WA".
cat > "$OUT/assembly.svg" <<'EOF'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="#e8f0ea" fill-rule="evenodd" role="img">
  <path d="M12 1.25a10.75 10.75 0 1 0 0 21.5a10.75 10.75 0 1 0 0-21.5z M7.74 14.209 6.588 12.487 5.428 14.209H4.114L5.898 11.753L4.198 9.455H5.529L6.588 11.01L7.643 9.455H8.983L7.282 11.74L9.08 14.209Z M14.199 12.249Q14.199 13.203 13.641 13.75Q13.083 14.297 12.116 14.297Q11.04 14.297 10.444 13.491Q9.849 12.685 9.849 11.256Q9.849 9.701 10.444 8.945Q11.04 8.189 12.147 8.189Q12.934 8.189 13.389 8.536Q13.844 8.883 14.032 9.613L12.868 9.775Q12.701 9.165 12.121 9.165Q11.62 9.165 11.339 9.641Q11.057 10.118 11.057 11.037Q11.255 10.707 11.607 10.531Q11.958 10.355 12.402 10.355Q13.215 10.355 13.707 10.867Q14.199 11.379 14.199 12.249ZM12.96 12.285Q12.96 11.806 12.716 11.535Q12.472 11.265 12.046 11.265Q11.651 11.265 11.398 11.509Q11.145 11.753 11.145 12.153Q11.145 12.649 11.405 12.992Q11.664 13.335 12.077 13.335Q12.486 13.335 12.723 13.054Q12.96 12.772 12.96 12.285Z M19.007 12.948V14.209H17.829V12.948H15.012V12.021L17.627 8.281H19.007V12.03H19.833V12.948ZM17.829 10.224Q17.829 9.986 17.845 9.709Q17.86 9.433 17.869 9.353Q17.755 9.6 17.456 10.065L16.05 12.03H17.829Z"/>
</svg>
EOF

cat > "$OUT/_fallback.svg" <<'EOF'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="#000">
  <path d="M12 2.5l1.1 4.2 4.3.2-3.3 2.8 1.1 4.2L12 11.7 8.8 13.9l1.1-4.2L6.6 6.9l4.3-.2L12 2.5z"/>
</svg>
EOF

cat > "$OUT/NOTICE.md" <<EOF
# Third-party icons

Language icons under this directory (except \`_fallback.svg\` and \`assembly.svg\`)
are vendored from [Simple Icons](https://github.com/simple-icons/simple-icons)
under **CC0 1.0**.

- Most icons: npm \`simple-icons@${SI_TAG}\`
- Ada: \`develop\` branch (\`icons/ada.svg\`)

\`_fallback.svg\` and \`assembly.svg\` (x64 badge for x86-64 NASM) are original
to wildling. Assembly is not the Simple Icons WebAssembly mark.

The site serves these glyphs as \`&lt;img&gt;\` with a light fill for the dark theme.
EOF

echo "Icons vendored into $OUT"
