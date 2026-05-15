# Claude Code Skills: Paper Summarizer & Zotero Manager

Two complementary Claude Code skills covering the full academic reading-to-archiving pipeline. Each skill is standalone — use them separately or together.

## Skills

### paper-summarizer-v2 — Read & Summarize

Turn papers into structured Markdown notes.

| | |
|---|---|
| **Input** | URL, DOI, PMID, arXiv ID, PDF file |
| **Output** | Structured Markdown notes (Chinese default, English on request) |
| **Modes** | Single paper, multi-paper, comparative analysis, literature survey |
| **Figures** | Best-effort extraction (local PDF) or text description |
| **Deps** | `curl`, `python3` |

### zotero-manager — Store & Organize

Universal interface to a Zotero library.

| | |
|---|---|
| **Import** | DOI, PMID, arXiv, PDF, manual metadata, paper-summarizer .md batch |
| **Notes** | Add/update/delete child notes with Markdown content |
| **Collections** | Auto-categorize by keyword, create/delete collections |
| **Tags** | Add/remove, batch tag by collection |
| **Search** | By title, author, DOI, tag, collection, date added |
| **PDF** | Find OA PDFs, import local PDFs, detect missing attachments |
| **Maintenance** | Find duplicates (DOI/title), orphan detection, bulk delete |
| **Deps** | Node.js >= 18, `curl`, `python3` |

> zotero-manager bundles a modified [@xevos117/mcp-zotero](https://github.com/xevos117/mcp-zotero) with the `add_item_note` tool.

## Quick Start

### 1. Install

Copy both directories to your Claude Code skills directory:

```
~/.claude/skills/paper-summarizer-v2/
~/.claude/skills/zotero-manager/
```

Or use a project-local skills directory.

### 2. Configure Zotero Manager (one-time)

```bash
bash <skills-dir>/zotero-manager/scripts/setup.sh
```

This installs npm dependencies and prompts for your Zotero API credentials. Get them at [zotero.org/settings/keys](https://www.zotero.org/settings/keys).

The setup script writes credentials to `.mcp.json` — credentials are never stored in the skill files.

### 3. Typical Workflow

```
Summarize a paper:
  → paper-summarizer-v2

Import summaries to Zotero:
  → zotero-manager (imports metadata, attaches notes, categorizes)
```

## Compatibility

| Platform | Support |
|----------|---------|
| Claude Code (CLI) | Full (MCP tools + curl fallback) |
| Claude.ai (Web) | Partial (curl fallback for Zotero) |
| Cowork | Full |

## License

MIT

## Credits

- `paper-summarizer-v2` — Community-developed paper reading & summarization skill
- `zotero-manager` — Built on [@xevos117/mcp-zotero](https://github.com/xevos117/mcp-zotero), extended with `add_item_note`
- Both skills are fully independent but designed to complement each other
