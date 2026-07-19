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
cp "$SITE_SRC/assets/icons/"*.svg "$OUT/assets/icons/"
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
<a class="lang-tile" href="languages/${lang}/" style="--icon: url('assets/icons/${icon_file}')">
  <span class="lang-tile__icon" aria-hidden="true"></span>
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
python3 - "$ROOT" "$OUT" "$LANGS_FILE" <<'PY'
import html
import pathlib
import re
import sys

try:
    import markdown
except ImportError:
    markdown = None

root = pathlib.Path(sys.argv[1])
out = pathlib.Path(sys.argv[2])
langs_file = pathlib.Path(sys.argv[3])

LABELS = {
    "javascript": "JavaScript",
    "python": "Python",
    "java": "Java",
    "csharp": "C#",
    "visualbasic": "Visual Basic",
    "cpp": "C++",
    "php": "PHP",
    "c": "C",
    "go": "Go",
    "rust": "Rust",
    "kotlin": "Kotlin",
    "ruby": "Ruby",
    "swift": "Swift",
    "scala": "Scala",
    "dart": "Dart",
    "posix-shell": "POSIX shell",
    "powershell": "PowerShell",
    "lua": "Lua",
    "assembly": "Assembly",
    "r": "R",
    "groovy": "Groovy",
    "perl": "Perl",
    "elixir": "Elixir",
    "pascal": "Pascal",
    "zig": "Zig",
    "fortran": "Fortran",
    "ada": "Ada",
    "fsharp": "F#",
    "haskell": "Haskell",
}

def simple_md(text: str) -> str:
    """Minimal fallback Markdown → HTML if the markdown package is absent."""
    lines = text.splitlines()
    out_parts = []
    in_code = False
    code_lang = ""
    code_buf = []
    para = []

    def flush_para():
        nonlocal para
        if para:
            out_parts.append("<p>" + " ".join(para) + "</p>")
            para = []

    def inline(s: str) -> str:
        s = html.escape(s)
        s = re.sub(r"`([^`]+)`", r"<code>\1</code>", s)
        s = re.sub(r"\[([^\]]+)\]\(([^)]+)\)", r'<a href="\2">\1</a>', s)
        s = re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", s)
        return s

    for line in lines:
        if line.startswith("```"):
            if in_code:
                out_parts.append(
                    "<pre><code>" + html.escape("\n".join(code_buf)) + "</code></pre>"
                )
                code_buf = []
                in_code = False
            else:
                flush_para()
                in_code = True
                code_lang = line[3:].strip()
            continue
        if in_code:
            code_buf.append(line)
            continue
        if not line.strip():
            flush_para()
            continue
        if line.startswith("### "):
            flush_para()
            out_parts.append("<h3>" + inline(line[4:]) + "</h3>")
        elif line.startswith("## "):
            flush_para()
            out_parts.append("<h2>" + inline(line[3:]) + "</h2>")
        elif line.startswith("# "):
            flush_para()
            out_parts.append("<h1>" + inline(line[2:]) + "</h1>")
        elif re.match(r"^[-*] ", line):
            flush_para()
            if not out_parts or not out_parts[-1].startswith("<ul"):
                out_parts.append("<ul>")
            out_parts.append("<li>" + inline(line[2:]) + "</li>")
        elif "|" in line and re.match(r"^\s*\|", line):
            flush_para()
            cells = [c.strip() for c in line.strip().strip("|").split("|")]
            if all(re.match(r"^:?-+:?$", c.replace(" ", "")) for c in cells):
                continue
            tag = "th" if not any("<table" in p for p in out_parts[-3:]) else "td"
            if tag == "th" or "<table>" not in "".join(out_parts[-5:]):
                out_parts.append("<table><thead><tr>")
                for c in cells:
                    out_parts.append(f"<th>{inline(c)}</th>")
                out_parts.append("</tr></thead><tbody>")
            else:
                out_parts.append("<tr>")
                for c in cells:
                    out_parts.append(f"<td>{inline(c)}</td>")
                out_parts.append("</tr>")
        else:
            if out_parts and out_parts[-1] == "<ul>":
                pass
            elif out_parts and out_parts[-1].startswith("<li>") and not line.startswith(("-", "*")):
                out_parts.append("</ul>")
            para.append(inline(line))
    flush_para()
    if out_parts and out_parts[-1].startswith("<li>"):
        out_parts.append("</ul>")
    if "<tbody>" in "".join(out_parts) and "</table>" not in "".join(out_parts):
        out_parts.append("</tbody></table>")
    return "\n".join(out_parts)


def render_md(text: str) -> str:
    if markdown is not None:
        return markdown.markdown(
            text,
            extensions=["fenced_code", "tables", "sane_lists"],
        )
    return simple_md(text)


TEMPLATE = """<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>{title} — wildling</title>
    <link rel="icon" href="../../assets/logo.svg" type="image/svg+xml" />
    <link rel="preconnect" href="https://fonts.googleapis.com" />
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
    <link href="https://fonts.googleapis.com/css2?family=IBM+Plex+Mono:wght@400;600&family=Syne:wght@500;700;800&display=swap" rel="stylesheet" />
    <link rel="stylesheet" href="../../assets/site.css" />
  </head>
  <body>
    <div class="wrap">
      <header class="site-header">
        <a class="brand" href="../../">
          <img class="brand__mark" src="../../assets/logo.svg" alt="" width="28" height="28" />
          wildling
        </a>
        <nav class="nav" aria-label="Primary">
          <a href="../../">Home</a>
          <a href="../../syntax.html">Syntax</a>
          <a href="../../sandbox.html">Sandbox</a>
          <a href="../../#languages">Languages</a>
        </nav>
      </header>
      <main class="prose">
        <p><a href="../../#languages">← All languages</a></p>
        {body}
      </main>
      <footer class="site-footer">
        <p>
          <a href="https://github.com/dotmonk/wildling/tree/main/{lang}">Source on GitHub</a>
          ·
          <a href="../../sandbox.html">Sandbox</a>
        </p>
      </footer>
    </div>
  </body>
</html>
"""

langs = [
    line.strip()
    for line in langs_file.read_text(encoding="utf-8").splitlines()
    if line.strip() and not line.strip().startswith("#")
]

for lang in langs:
    readme = root / lang / "README.md"
    if readme.is_file():
        text = readme.read_text(encoding="utf-8")
        text = text.replace("](../docs/", "](https://github.com/dotmonk/wildling/blob/main/docs/")
        text = text.replace("](../tests/", "](https://github.com/dotmonk/wildling/tree/main/tests/")
        text = text.replace("](../dictionaries/", "](https://github.com/dotmonk/wildling/tree/main/dictionaries/")
        body = render_md(text)
        body = body.replace('href="../docs/', 'href="https://github.com/dotmonk/wildling/blob/main/docs/')
        body = body.replace('href="../tests/', 'href="https://github.com/dotmonk/wildling/tree/main/tests/')
        body = body.replace('href="../dictionaries/', 'href="https://github.com/dotmonk/wildling/tree/main/dictionaries/')
    else:
        body = f"<p>No README for <code>{html.escape(lang)}</code>.</p>"
    label = LABELS.get(lang, lang)
    page_dir = out / "languages" / lang
    page_dir.mkdir(parents=True, exist_ok=True)
    (page_dir / "index.html").write_text(
        TEMPLATE.format(title=html.escape(label), body=body, lang=lang),
        encoding="utf-8",
    )

print(f"Rendered {len(langs)} language pages", file=sys.stderr)
PY

rm -f "$OUT/.lang-wall.html" "$OUT/.lang-wall-block.html"

# Base path note for project Pages (username.github.io/wildling/)
# Relative links are used throughout so both / and /wildling/ work when
# deployed as a project site.

echo "Site built at $OUT"
