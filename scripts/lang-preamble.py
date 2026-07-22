#!/usr/bin/env python3
"""Shared language preamble for READMEs and GitHub Pages.

Data: site/lang-meta.json + docs/snippets/example.md

Usage:
  python3 scripts/lang-preamble.py markdown <lang>   # print markdown block
  python3 scripts/lang-preamble.py html-links <lang>
  python3 scripts/lang-preamble.py html-example <lang>
  python3 scripts/lang-preamble.py sync-readmes      # rewrite README markers
"""
from __future__ import annotations

import html
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
META_PATH = ROOT / "site" / "lang-meta.json"
EXAMPLE_PATH = ROOT / "docs" / "snippets" / "example.md"
LANGS_FILE = ROOT / "languages.txt"

BEGIN = "<!-- wildling:preamble -->"
END = "<!-- /wildling:preamble -->"


def load_meta() -> dict:
    return json.loads(META_PATH.read_text(encoding="utf-8"))


def load_example_md() -> str:
    return EXAMPLE_PATH.read_text(encoding="utf-8").strip() + "\n"


def lang_ids() -> list[str]:
    return [
        line.strip()
        for line in LANGS_FILE.read_text(encoding="utf-8").splitlines()
        if line.strip() and not line.strip().startswith("#")
    ]


def markdown_links(lang: str, meta: dict | None = None) -> str:
    meta = meta or load_meta()
    info = meta["languages"].get(lang, {"label": lang, "registries": []})
    lines = [
        f"**Docs:** [Website]({meta['website']}) · [Sandbox]({meta['sandbox']}) · [Syntax]({meta['syntax']}) · [Source]({meta['repo']}/tree/main/{lang})",
    ]
    regs = info.get("registries") or []
    if regs:
        parts = [f"[{r['name']}]({r['url']})" for r in regs]
        lines.append("")
        lines.append("**Registry:** " + " · ".join(parts))
    lines.append("")
    return "\n".join(lines) + "\n"


def markdown_preamble(lang: str, meta: dict | None = None) -> str:
    return markdown_links(lang, meta) + load_example_md()


def _inline_md(raw: str) -> str:
    out = []
    i = 0
    while i < len(raw):
        if raw.startswith("**", i):
            j = raw.find("**", i + 2)
            if j != -1:
                out.append("<strong>" + html.escape(raw[i + 2 : j]) + "</strong>")
                i = j + 2
                continue
        if raw[i] == "`":
            j = raw.find("`", i + 1)
            if j == -1:
                out.append(html.escape(raw[i:]))
                break
            out.append("<code>" + html.escape(raw[i + 1 : j]) + "</code>")
            i = j + 1
        elif raw[i] == "[":
            m = re.match(r"\[([^\]]+)\]\(([^)]+)\)", raw[i:])
            if m:
                out.append(
                    f'<a href="{html.escape(m.group(2))}">{html.escape(m.group(1))}</a>'
                )
                i += m.end()
            else:
                out.append(html.escape(raw[i]))
                i += 1
        else:
            out.append(html.escape(raw[i]))
            i += 1
    return "".join(out)


def html_links(lang: str, meta: dict | None = None) -> str:
    meta = meta or load_meta()
    info = meta["languages"].get(lang, {"label": lang, "registries": []})
    docs = [
        f'<a href="{html.escape(meta["website"])}">Website</a>',
        f'<a href="{html.escape(meta["sandbox"])}">Sandbox</a>',
        f'<a href="{html.escape(meta["syntax"])}">Syntax</a>',
        f'<a href="{html.escape(meta["repo"])}/tree/main/{html.escape(lang)}">Source</a>',
    ]
    parts = [
        '<p class="lang-links"><strong>Docs:</strong> ' + " · ".join(docs) + "</p>",
    ]
    regs = info.get("registries") or []
    if regs:
        reg_links = [
            f'<a href="{html.escape(r["url"])}">{html.escape(r["name"])}</a>' for r in regs
        ]
        parts.append(
            '<p class="lang-links"><strong>Registry:</strong> '
            + " · ".join(reg_links)
            + "</p>"
        )
    return "\n".join(parts) + "\n"


def html_example(_lang: str = "", meta: dict | None = None) -> str:
    del meta  # unused; example is shared
    example_html = []
    in_list = False
    in_code = False
    code_buf: list[str] = []
    title = "Example"
    for line in load_example_md().splitlines():
        if line.startswith("```"):
            if in_code:
                example_html.append(
                    "<pre><code>"
                    + html.escape("\n".join(code_buf))
                    + "</code></pre>"
                )
                code_buf = []
                in_code = False
            else:
                if in_list:
                    example_html.append("</ul>")
                    in_list = False
                in_code = True
            continue
        if in_code:
            code_buf.append(line)
            continue
        if line.startswith("## "):
            if in_list:
                example_html.append("</ul>")
                in_list = False
            title = line[3:].strip() or title
            continue
        if re.match(r"^[-*] ", line):
            if not in_list:
                example_html.append("<ul>")
                in_list = True
            example_html.append(f"<li>{_inline_md(line[2:])}</li>")
            continue
        if in_list:
            example_html.append("</ul>")
            in_list = False
        if not line.strip():
            continue
        example_html.append(f"<p>{_inline_md(line)}</p>")
    if in_list:
        example_html.append("</ul>")
    if in_code and code_buf:
        example_html.append(
            "<pre><code>" + html.escape("\n".join(code_buf)) + "</code></pre>"
        )
    return (
        f"<h2>{html.escape(title)}</h2>\n"
        '<aside class="lang-example">\n'
        + "\n".join(example_html)
        + "\n</aside>\n"
    )


def html_preamble(lang: str, meta: dict | None = None) -> str:
    """Full block (links + boxed example) — kept for ad-hoc use."""
    return html_links(lang, meta) + html_example(lang, meta)


def strip_preamble(text: str) -> str:
    if BEGIN in text and END in text:
        text = re.sub(
            re.escape(BEGIN) + r".*?" + re.escape(END) + r"\n*",
            "",
            text,
            count=1,
            flags=re.DOTALL,
        )
    return text


def sync_readme(lang: str, meta: dict) -> bool:
    path = ROOT / lang / "README.md"
    if not path.is_file():
        print(f"skip missing {path}", file=sys.stderr)
        return False
    text = strip_preamble(path.read_text(encoding="utf-8"))
    block = f"{BEGIN}\n{markdown_preamble(lang, meta).rstrip()}\n{END}\n"

    # Place after title + description, before the first ## section (Install, etc.).
    lines = text.splitlines(keepends=True)
    insert_at = None
    seen_h1 = False
    for i, line in enumerate(lines):
        if line.startswith("# ") and not line.startswith("## "):
            seen_h1 = True
            continue
        if seen_h1 and line.startswith("## "):
            insert_at = i
            break

    if insert_at is None:
        new_text = text.rstrip() + "\n\n" + block
    else:
        before = "".join(lines[:insert_at]).rstrip() + "\n\n"
        after = "".join(lines[insert_at:])
        if not after.startswith("\n") and before.endswith("\n\n"):
            new_text = before + block + "\n" + after
        else:
            new_text = before + block + "\n" + after.lstrip("\n")

    if new_text != path.read_text(encoding="utf-8"):
        path.write_text(new_text, encoding="utf-8")
        return True
    return False


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print(__doc__, file=sys.stderr)
        return 2
    cmd = argv[1]
    meta = load_meta()
    if cmd == "markdown":
        print(markdown_preamble(argv[2], meta), end="")
        return 0
    if cmd == "html":
        print(html_preamble(argv[2], meta), end="")
        return 0
    if cmd == "html-links":
        print(html_links(argv[2], meta), end="")
        return 0
    if cmd == "html-example":
        print(html_example(argv[2], meta), end="")
        return 0
    if cmd == "sync-readmes":
        n = 0
        for lang in lang_ids():
            if sync_readme(lang, meta):
                n += 1
                print(f"updated {lang}/README.md")
            else:
                print(f"unchanged {lang}/README.md")
        print(f"done ({n} files changed)", file=sys.stderr)
        return 0
    print(f"unknown command: {cmd}", file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
