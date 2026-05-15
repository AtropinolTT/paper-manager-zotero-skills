#!/usr/bin/env python3
"""Convert Markdown to Zotero-compatible HTML.

Zotero notes are stored as rich text (HTML, rendered by ProseMirror).
Raw Markdown posted via API is stored as plain text — line breaks and
formatting are lost. BetterNotes' "Syncing" feature converts between
Markdown files and HTML notes; this script mimics that conversion for
API-inserted notes.

Usage:
    python3 md2html.py < input.md > output.html
    python3 md2html.py file.md
"""

import re
import sys


def md2html(text: str) -> str:
    lines = text.split("\n")
    out = []
    in_code_block = False
    in_list = None  # "ul" or "ol"
    in_quote = False

    i = 0
    while i < len(lines):
        line = lines[i]

        # Code block (fenced)
        if line.strip().startswith("```"):
            if in_code_block:
                out.append("</code></pre>")
                in_code_block = False
            else:
                lang = line.strip()[3:].strip()
                if lang:
                    out.append(f'<pre><code class="language-{lang}">')
                else:
                    out.append("<pre><code>")
                in_code_block = True
            i += 1
            continue

        if in_code_block:
            out.append(_escape_html(line))
            i += 1
            continue

        # Horizontal rule
        if re.match(r"^[-*_]{3,}\s*$", line.strip()):
            if in_list:
                out.append(f"</{in_list}>")
                in_list = None
            if in_quote:
                out.append("</blockquote>")
                in_quote = False
            out.append("<hr>")
            i += 1
            continue

        # Headings
        m = re.match(r"^(#{1,6})\s+(.+)$", line)
        if m:
            if in_list:
                out.append(f"</{in_list}>")
                in_list = None
            if in_quote:
                out.append("</blockquote>")
                in_quote = False
            level = len(m.group(1))
            content = _inline_format(m.group(2))
            out.append(f"<h{level}>{content}</h{level}>")
            i += 1
            continue

        # Blockquote
        m = re.match(r"^>\s?(.*)$", line)
        if m:
            if in_list:
                out.append(f"</{in_list}>")
                in_list = None
            if not in_quote:
                out.append("<blockquote>")
                in_quote = True
            out.append(f"<p>{_inline_format(m.group(1))}</p>")
            i += 1
            continue
        elif in_quote:
            out.append("</blockquote>")
            in_quote = False

        # Unordered list
        m = re.match(r"^(\s*)[-*+]\s+(.+)$", line)
        if m:
            if in_list != "ul":
                if in_list:
                    out.append(f"</{in_list}>")
                out.append("<ul>")
                in_list = "ul"
            out.append(f"<li>{_inline_format(m.group(2))}</li>")
            i += 1
            continue

        # Ordered list
        m = re.match(r"^(\s*)\d+[.)]\s+(.+)$", line)
        if m:
            if in_list != "ol":
                if in_list:
                    out.append(f"</{in_list}>")
                out.append("<ol>")
                in_list = "ol"
            out.append(f"<li>{_inline_format(m.group(2))}</li>")
            i += 1
            continue

        # Close list if we were in one
        if in_list and line.strip() == "":
            # Don't close yet — might be a loose list item
            i += 1
            continue
        elif in_list and line.strip():
            # Check if next line is still part of the list
            out.append(f"</{in_list}>")
            in_list = None
            # Fall through to paragraph

        # Empty line
        if line.strip() == "":
            i += 1
            continue

        # Paragraph (default)
        if in_list:
            out.append(f"</{in_list}>")
            in_list = None
        out.append(f"<p>{_inline_format(line)}</p>")
        i += 1

    # Close any open elements
    if in_code_block:
        out.append("</code></pre>")
    if in_list:
        out.append(f"</{in_list}>")
    if in_quote:
        out.append("</blockquote>")

    return "\n".join(out)


def _inline_format(text: str) -> str:
    """Convert inline Markdown to HTML."""
    # Escape HTML first
    text = _escape_html(text)

    # Bold (** or __)
    text = re.sub(r"\*\*(.+?)\*\*", r"<b>\1</b>", text)
    text = re.sub(r"__(.+?)__", r"<b>\1</b>", text)

    # Italic (* or _)
    text = re.sub(r"\*(.+?)\*", r"<i>\1</i>", text)
    text = re.sub(r"_(.+?)_", r"<i>\1</i>", text)

    # Inline code
    text = re.sub(r"`([^`]+)`", r"<code>\1</code>", text)

    # Links
    text = re.sub(r'\[([^\]]+)\]\(([^)]+)\)', r'<a href="\2">\1</a>', text)

    # Strikethrough
    text = re.sub(r"~~(.+?)~~", r"<s>\1</s>", text)

    return text


def _escape_html(text: str) -> str:
    return text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


if __name__ == "__main__":
    if len(sys.argv) > 1:
        with open(sys.argv[1], "r", encoding="utf-8") as f:
            content = f.read()
    else:
        content = sys.stdin.read()
    print(md2html(content))
