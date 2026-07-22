#!/usr/bin/env python3
"""Render language README pages into _site/languages/<lang>/index.html."""
from __future__ import annotations

import html
import pathlib
import re
import sys
from importlib.machinery import SourceFileLoader

try:
    import markdown
except ImportError:
    markdown = None

ROOT = pathlib.Path(__file__).resolve().parents[1]
preamble_mod = SourceFileLoader(
    "lang_preamble",
    str(ROOT / "scripts" / "lang-preamble.py"),
).load_module()

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
    lines = text.splitlines()
    out_parts = []
    in_code = False
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
            if "<table>" not in "".join(out_parts[-5:]):
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
            if out_parts and out_parts[-1].startswith("<li>") and not line.startswith(
                ("-", "*")
            ):
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


def strip_preamble_markers(text: str) -> str:
    return preamble_mod.strip_preamble(text)


def split_intro_rest(text: str) -> tuple[str, str]:
    """Split README into title+description and the first ## section onward."""
    lines = text.splitlines(keepends=True)
    for i, line in enumerate(lines):
        if line.startswith("## "):
            return "".join(lines[:i]).rstrip() + "\n", "".join(lines[i:])
    return text, ""


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
        {intro}
        {links}
        {example}
        {rest}
      </main>
      <footer class="site-footer">
        <p>
          <a href="https://github.com/dotmonk/wildling/tree/main/{lang}">Source on GitHub</a>
          ·
          <a href="https://dotmonk.github.io/wildling/">Website</a>
          ·
          <a href="../../sandbox.html">Sandbox</a>
        </p>
      </footer>
    </div>
  </body>
</html>
"""


def rewrite_local_links(text: str) -> str:
    text = text.replace(
        "](../docs/", "](https://github.com/dotmonk/wildling/blob/main/docs/"
    )
    text = text.replace(
        "](../tests/", "](https://github.com/dotmonk/wildling/tree/main/tests/"
    )
    text = text.replace(
        "](../dictionaries/",
        "](https://github.com/dotmonk/wildling/tree/main/dictionaries/",
    )
    return text


def rewrite_html_links(body: str) -> str:
    body = body.replace(
        'href="../docs/',
        'href="https://github.com/dotmonk/wildling/blob/main/docs/',
    )
    body = body.replace(
        'href="../tests/',
        'href="https://github.com/dotmonk/wildling/tree/main/tests/',
    )
    body = body.replace(
        'href="../dictionaries/',
        'href="https://github.com/dotmonk/wildling/tree/main/dictionaries/',
    )
    return body


def main() -> int:
    root = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT
    out = pathlib.Path(sys.argv[2]) if len(sys.argv) > 2 else root / "_site"
    langs_file = pathlib.Path(sys.argv[3]) if len(sys.argv) > 3 else root / "languages.txt"

    langs = [
        line.strip()
        for line in langs_file.read_text(encoding="utf-8").splitlines()
        if line.strip() and not line.strip().startswith("#")
    ]
    meta = preamble_mod.load_meta()

    for lang in langs:
        readme = root / lang / "README.md"
        if readme.is_file():
            text = strip_preamble_markers(readme.read_text(encoding="utf-8"))
            text = rewrite_local_links(text)
            intro_md, rest_md = split_intro_rest(text)
            intro = rewrite_html_links(render_md(intro_md))
            rest = rewrite_html_links(render_md(rest_md)) if rest_md.strip() else ""
        else:
            intro = f"<p>No README for <code>{html.escape(lang)}</code>.</p>"
            rest = ""
        label = LABELS.get(lang, lang)
        page_dir = out / "languages" / lang
        page_dir.mkdir(parents=True, exist_ok=True)
        (page_dir / "index.html").write_text(
            TEMPLATE.format(
                title=html.escape(label),
                intro=intro,
                links=preamble_mod.html_links(lang, meta),
                example=preamble_mod.html_example(lang, meta),
                rest=rest,
                lang=lang,
            ),
            encoding="utf-8",
        )

    print(f"Rendered {len(langs)} language pages", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
