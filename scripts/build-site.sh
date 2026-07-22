#!/bin/sh
# Assemble the GitHub Pages site into _site/
set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SITE_SRC="$ROOT/site"
OUT="$ROOT/_site"
LANGS_FILE="$ROOT/languages.txt"

cd "$ROOT"

rm -rf "$OUT"
mkdir -p "$OUT/assets/icons" "$OUT/languages"

# --- browser bundle (library only; no Node CLI) ---
if [ ! -d "$ROOT/javascript/node_modules" ]; then
    (cd "$ROOT/javascript" && npm ci --include=dev)
fi
npx --yes esbuild@0.25.0 \
    "$ROOT/javascript/src/index.ts" \
    --bundle \
    --format=iife \
    --global-name=wildlingExports \
    --platform=browser \
    --target=es2020 \
    --outfile="$OUT/assets/wildling.raw.js"

# Wrap so window.wildling is the default export function
{
    cat "$OUT/assets/wildling.raw.js"
    printf '\nwindow.wildling = (wildlingExports && wildlingExports.default) ? wildlingExports.default : wildlingExports;\n'
} > "$OUT/assets/wildling.js"
rm -f "$OUT/assets/wildling.raw.js"

# --- static assets ---
cp "$SITE_SRC/assets/site.css" "$OUT/assets/site.css"
cp "$SITE_SRC/assets/sandbox.js" "$OUT/assets/sandbox.js"
# Prefer the site-tuned (lime) logo for Pages; keep assets/logo.svg for README.
cp "$SITE_SRC/assets/logo.svg" "$OUT/assets/logo.svg"
find "$SITE_SRC/assets/icons" -maxdepth 1 -type f \( -name '*.svg' -o -name 'NOTICE.md' \) \
    -exec cp {} "$OUT/assets/icons/" \;
cp "$SITE_SRC/syntax.html" "$OUT/syntax.html"
cp "$SITE_SRC/sandbox.html" "$OUT/sandbox.html"

# --- language display names ---
lang_label() {
    case "$1" in
        javascript) echo "JavaScript" ;;
        python) echo "Python" ;;
        java) echo "Java" ;;
        csharp) echo "C#" ;;
        visualbasic) echo "Visual Basic" ;;
        cpp) echo "C++" ;;
        php) echo "PHP" ;;
        c) echo "C" ;;
        go) echo "Go" ;;
        rust) echo "Rust" ;;
        kotlin) echo "Kotlin" ;;
        ruby) echo "Ruby" ;;
        swift) echo "Swift" ;;
        scala) echo "Scala" ;;
        dart) echo "Dart" ;;
        posix-shell) echo "POSIX shell" ;;
        powershell) echo "PowerShell" ;;
        lua) echo "Lua" ;;
        assembly) echo "Assembly" ;;
        r) echo "R" ;;
        groovy) echo "Groovy" ;;
        perl) echo "Perl" ;;
        elixir) echo "Elixir" ;;
        pascal) echo "Pascal" ;;
        zig) echo "Zig" ;;
        fortran) echo "Fortran" ;;
        ada) echo "Ada" ;;
        fsharp) echo "F#" ;;
        haskell) echo "Haskell" ;;
        *) echo "$1" ;;
    esac
}

# --- language icon wall HTML ---
WALL="$OUT/.lang-wall.html"
: > "$WALL"
while IFS= read -r lang || [ -n "$lang" ]; do
    case "$lang" in ''|\#*) continue ;; esac
    label="$(lang_label "$lang")"
    icon="assets/icons/${lang}.svg"
    if [ ! -f "$OUT/$icon" ]; then
        icon="assets/icons/_fallback.svg"
    fi
    icon_file="$(basename "$icon")"
    cat >> "$WALL" <<EOF
<a class="lang-tile" href="languages/${lang}/">
  <img class="lang-tile__icon" src="assets/icons/${icon_file}" alt="" width="36" height="36" decoding="async" />
  <span class="lang-tile__name">${label}</span>
</a>
EOF
done < "$LANGS_FILE"

WALL_INNER="$(
    printf '%s\n' '<div class="lang-wall">'
    cat "$WALL"
    printf '%s\n' '</div>'
)"

# Escape for Python triple-quoted? We'll use a file and Python replace.
printf '%s\n' "$WALL_INNER" > "$OUT/.lang-wall-block.html"

python3 - "$SITE_SRC/index.html" "$OUT/index.html" "$OUT/.lang-wall-block.html" <<'PY'
import pathlib, sys
src, dst, wall = map(pathlib.Path, sys.argv[1:4])
html = src.read_text(encoding="utf-8")
block = wall.read_text(encoding="utf-8")
if "<!--LANG_WALL-->" not in html:
    raise SystemExit("index.html missing <!--LANG_WALL--> marker")
dst.write_text(html.replace("<!--LANG_WALL-->", block), encoding="utf-8")
PY

# --- render language READMEs ---
python3 "$ROOT/scripts/render-lang-pages.py" "$ROOT" "$OUT" "$LANGS_FILE"

rm -f "$OUT/.lang-wall.html" "$OUT/.lang-wall-block.html"

# Base path note for project Pages (username.github.io/wildling/)
# Relative links are used throughout so both / and /wildling/ work when
# deployed as a project site.

echo "Site built at $OUT"
