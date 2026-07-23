#!/bin/sh
# Assemble the GitHub Pages site into _site/
set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SITE_SRC="$ROOT/site"
OUT="$ROOT/_site"
LANGS_FILE="$ROOT/languages.txt"
META_FILE="$ROOT/site/lang-meta.json"

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

# --- demo dictionaries (from repo dictionaries/*.txt) ---
python3 - "$ROOT/dictionaries" "$SITE_SRC/assets/demo-dictionaries.json" <<'PY'
import json, pathlib, sys
src, dst = map(pathlib.Path, sys.argv[1:3])
out = {}
for path in sorted(src.glob("*.txt")):
    words = [ln.strip() for ln in path.read_text(encoding="utf-8").splitlines() if ln.strip()]
    out[path.stem] = words
dst.write_text(json.dumps(out, indent=2) + "\n", encoding="utf-8")
PY

# --- static assets ---
cp "$SITE_SRC/assets/site.css" "$OUT/assets/site.css"
cp "$SITE_SRC/assets/sandbox.js" "$OUT/assets/sandbox.js"
cp "$SITE_SRC/assets/demo-dictionaries.json" "$OUT/assets/demo-dictionaries.json"
# Prefer the site-tuned (lime) logo for Pages; keep assets/logo.svg for README.
cp "$SITE_SRC/assets/logo.svg" "$OUT/assets/logo.svg"
find "$SITE_SRC/assets/icons" -maxdepth 1 -type f \( -name '*.svg' -o -name 'NOTICE.md' \) \
    -exec cp {} "$OUT/assets/icons/" \;
cp "$SITE_SRC/syntax.html" "$OUT/syntax.html"
cp "$SITE_SRC/sandbox.html" "$OUT/sandbox.html"
cp "$SITE_SRC/cookbook.html" "$OUT/cookbook.html"

# --- language wall from languages.txt + lang-meta.json ---
python3 - "$LANGS_FILE" "$META_FILE" "$OUT" <<'PY'
import json, pathlib, sys

langs_file, meta_file, out_dir = map(pathlib.Path, sys.argv[1:4])
meta = json.loads(meta_file.read_text(encoding="utf-8"))
lang_meta = meta.get("languages") or {}

def publish_kind(entry):
    regs = (entry or {}).get("registries") or []
    if not regs:
        return "git"
    names = [str(r.get("name") or "") for r in regs]
    if any(n == "GitHub Releases" for n in names):
        return "releases"
    if all(n.startswith("Git") for n in names):
        return "git"
    return "registry"

lines = ['<div class="lang-wall">']
for raw in langs_file.read_text(encoding="utf-8").splitlines():
    lang = raw.strip()
    if not lang or lang.startswith("#"):
        continue
    entry = lang_meta.get(lang) or {}
    label = entry.get("label") or lang
    kind = publish_kind(entry)
    icon = f"assets/icons/{lang}.svg"
    if not (out_dir / icon).is_file():
        icon = "assets/icons/_fallback.svg"
    icon_file = pathlib.Path(icon).name
    lines.append(
        f'<a class="lang-tile" href="languages/{lang}/">\n'
        f'  <img class="lang-tile__icon" src="assets/icons/{icon_file}" alt="" width="36" height="36" decoding="async" />\n'
        f'  <span class="lang-tile__name">{label}</span>\n'
        f'  <span class="lang-tile__badge">{kind}</span>\n'
        f"</a>"
    )
lines.append("</div>")
(out_dir / ".lang-wall-block.html").write_text("\n".join(lines) + "\n", encoding="utf-8")
PY

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
