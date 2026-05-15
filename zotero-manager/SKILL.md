---
name: zotero-manager
description: Universal Zotero library manager. Import papers via DOI/PMID/PDF/manual metadata, parse paper-summarizer markdown for batch import, manage notes/collections/tags, search and browse the library, attach PDFs, deduplicate. Use whenever the user wants to add, organize, search, or maintain anything in Zotero. Triggers on: 添加到Zotero, 导入Zotero, 导入文献, Zotero搜索, 查Zotero, 文献管理, 整理Zotero, Zotero笔记, Zotero标签, Zotero目录, add to zotero, zotero import, zotero note, zotero collection, zotero tag, find in my library, organize my papers, batch import to zotero, zotero PDF.
version: 1.0.0
license: MIT
tags: [zotero, literature-management, reference-manager, academic]
---

# Zotero Manager

Universal interface to a Zotero library. Import anything into Zotero, attach notes, organize into collections and tags, search the library, manage PDFs, and maintain a clean library.

**Companion skill:** `paper-summarizer-v2` handles reading and summarizing papers. This skill handles everything on the Zotero side — the two ship together and cover the full reading-to-archiving pipeline.

## Prerequisites

The bundled mcp-zotero (in `assets/mcp-zotero/`) is a modified version that includes the `add_item_note` tool for attaching notes to Zotero items.

**One-time setup:**
```bash
bash <skill-directory>/scripts/setup.sh
```
This installs npm dependencies and prompts for Zotero API credentials.

## Credential Management

Credentials are **never stored in skill files**. The setup script supports two modes:

- **Save to .mcp.json** (default): Credentials written to the project's `.mcp.json` `env` field. The MCP server picks them up automatically.
- **Session-only**: Enter credentials when prompted each session. Nothing persisted.

Credentials needed:
- `ZOTERO_API_KEY` — create at https://www.zotero.org/settings/keys
- `ZOTERO_USER_ID` — numeric ID shown on the same page

If the MCP server is not running after setup, restart Claude Code or reload the MCP server.

## Capabilities

All operations use Zotero MCP tools when available, falling back to curl + Zotero REST API otherwise. MCP tools are preferred because they handle auth, error formatting, and PDF resolution.

### 1. Import

Add papers to Zotero from any source. Always check for existing entries (by DOI) before creating new ones.

**By DOI (preferred for accuracy):**
```
mcp__zotero__add_items_by_doi(dois=["<DOI>"], tags=["<optional-tags>"])
```

**By PMID:**
Resolve PMID to DOI via PubMed API first, then use `add_items_by_doi`:
```bash
curl -s "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esummary.fcgi?db=pubmed&id=<PMID>&retmode=json"
```
Extract `elocationid` (DOI) from the response, strip the `doi: ` prefix.

**By arXiv ID:**
Resolve via arXiv API to get title and authors, search Zotero by title:
```bash
curl -s "https://export.arxiv.org/api/query?id_list=<ARXIV_ID>"
```

**By title (last resort):**
Search Zotero by title first. If not found, search PubMed/CrossRef to find a DOI, then `add_items_by_doi`.

**By PDF file:**
```
mcp__zotero__import_pdf_to_zotero(file_path="<path>")
```
Zotero auto-extracts metadata from the PDF when possible.

**By manual metadata (no DOI):**
```
mcp__zotero__add_items(items=[{
  itemType: "journalArticle",
  title: "...",
  date: "2025",
  publicationTitle: "...",
  creators: [{firstName: "...", lastName: "..."}],
  abstractNote: "..."
}])
```
Creators must have either `firstName`+`lastName` or just `name` (for institutional authors).

**Batch from paper-summarizer .md files:**
When given a directory of paper-summarizer-v2 output files:
1. For each `.md`, extract DOI and PMID from the header block
2. Papers with DOI → Step 3 (check + add)
3. Papers without DOI but with PMID → resolve via PubMed → add by DOI
4. Papers with neither → search by title → add manually
5. Attach the full Markdown content as a child note (see Capability 2)

### 2. Note Management

Notes are Zotero child items (`itemType: "note"`) attached to a parent item. Notes support HTML content — plain text and Markdown are stored as-is and rendered in the Zotero UI.

**Add a note:**
```
mcp__zotero__add_item_note(parent_item="<ITEM_KEY>", note="<CONTENT>", tags=["<optional-tags>"])
```

**Fallback via curl** (if `add_item_note` MCP tool is unavailable):
```bash
curl -s -X POST "https://api.zotero.org/users/<USER_ID>/items" \
  -H "Zotero-API-Key: <API_KEY>" \
  -H "Content-Type: application/json" \
  -d "$(python3 -c "import json; print(json.dumps([{'itemType':'note','note':open('note.md').read(),'parentItem':'<KEY>','tags':[{'tag':'t1'}]}]))")"
```

**Update a note:**
Get the note's current version, then PATCH:
```bash
curl -s -X PATCH "https://api.zotero.org/users/<USER_ID>/items/<NOTE_KEY>" \
  -H "Zotero-API-Key: <API_KEY>" \
  -H "Content-Type: application/json" \
  -H "If-Unmodified-Since-Version: <VERSION>" \
  -d '{"note": "<NEW_CONTENT>"}'
```

**Delete a note:**
```
mcp__zotero__delete_items(item_keys=["<NOTE_KEY>"])
```

**List notes on an item:**
```bash
curl -s "https://api.zotero.org/users/<USER_ID>/items/<ITEM_KEY>/children?format=json" \
  -H "Zotero-API-Key: <API_KEY>"
```
Filter for `itemType: "note"`.

**Bulk note import from .md files:**
When mapping `.md` files to Zotero items, use the file content as note text. Read each file, escape properly for JSON (use `python3 -c "import json; print(json.dumps(content))"`), and POST as a note child item.

### 3. Collection Management

Collections are Zotero's folder system. Items can belong to multiple collections.

**View collection tree:**
```
mcp__zotero__get_collections()
```
Returns flat list with `key`, `name`, `parentCollection` fields. Reconstruct the tree from `parentCollection` references.

**Create a collection:**
```
mcp__zotero__create_collection(name="<NAME>", parent_collection="<PARENT_KEY>")
```
Omit `parent_collection` to create at root level.

**Delete a collection:**
```
mcp__zotero__delete_collection(collection_key="<KEY>")
```
This only deletes the collection, not the items inside it.

**Add items to a collection:**
```bash
curl -s -X POST "https://api.zotero.org/users/<USER_ID>/collections/<COLLECTION_KEY>/items" \
  -H "Zotero-API-Key: <API_KEY>" \
  -H "Content-Type: application/json" \
  -d '["<ITEM_KEY_1>","<ITEM_KEY_2>"]'
```

**Remove items from a collection:**
```bash
curl -s -X DELETE "https://api.zotero.org/users/<USER_ID>/collections/<COLLECTION_KEY>/items" \
  -H "Zotero-API-Key: <API_KEY>" \
  -H "Content-Type: application/json" \
  -d '["<ITEM_KEY_1>"]'
```

**Auto-categorize papers:**
When importing or organizing, match paper topics to existing collections by keyword. The mapping is domain-adaptive — fetch the user's current collection tree, then match against collection names and paper content:

1. Fetch `get_collections()` to build the current tree
2. For each paper, check title + abstract + tags against collection names
3. Papers with strong matches (collection name appears in title/abstract, or paper keywords match collection name) → add to that collection
4. Papers with no clear match → leave uncategorized (user can organize later)
5. Always report the categorization decisions so the user can review

**Do NOT hardcode collection keys** — they differ between Zotero accounts. Always fetch fresh and match by name.

### 4. Tag Management

Tags are flat (no hierarchy) and can be colored in the Zotero UI.

**Add tags during import:**
Pass `tags` array to `add_items_by_doi` or `add_items`.

**Add tags to existing items:**
```bash
curl -s -X POST "https://api.zotero.org/users/<USER_ID>/items/<ITEM_KEY>/tags" \
  -H "Zotero-API-Key: <API_KEY>" \
  -H "Content-Type: application/json" \
  -d '["tag1", "tag2"]'
```

**Remove tags:**
```bash
curl -s -X DELETE "https://api.zotero.org/users/<USER_ID>/items/<ITEM_KEY>/tags" \
  -H "Zotero-API-Key: <API_KEY>" \
  -H "Content-Type: application/json" \
  -d '["tag-to-remove"]'
```

**Batch tag by collection:**
Get items in a collection via `get_collection_items`, then loop-add tags.

**Suggested default tags for imported papers:**
- `paper-summary` — has an AI-generated or user-written summary note attached
- `AI-generated` — note content was auto-generated (so user can filter later)

### 5. Search & Browse

**Search by keyword (title, author, any field):**
```
mcp__zotero__search_library(query="<QUERY>", limit=25)
```

**Search by DOI:**
The Zotero API search sometimes fails for DOIs. Fallback: fetch all items and match locally:
```bash
curl -s "https://api.zotero.org/users/<USER_ID>/items?limit=100&format=json&itemType=journalArticle" \
  -H "Zotero-API-Key: <API_KEY>"
```

**List items in a collection:**
```
mcp__zotero__get_collection_items(collection_key="<KEY>", limit=50)
```

**View item details:**
```
mcp__zotero__get_items_details(item_keys=["<KEY_1>","<KEY_2>"], include_abstract=true)
```
This returns full metadata including notes, tags, attachments, and collection membership.

**Get full text of an item (if PDF attached):**
```
mcp__zotero__get_item_fulltext(item_key="<KEY>")
```

**Browse by date added:**
```
mcp__zotero__search_library(sort="dateAdded", direction="desc", limit=20)
```

### 6. PDF Management

**Find and attach OA PDFs for items without them:**
```
mcp__zotero__find_and_attach_pdfs(item_keys=["<KEY_1>","<KEY_2>"])
```

**Import a local PDF file:**
```
mcp__zotero__import_pdf_to_zotero(file_path="<path>", tags=["<optional>"])
```

**Detect items missing PDFs:**
Get items in a collection, use `get_items_details` to check for `itemType: "attachment"` children with `contentType: "application/pdf"`. Report items without PDF attachments.

**Storage quota note:** Zotero free accounts have limited cloud storage. If the quota is full, PDF attachment will fail but metadata operations still work. Warn the user when this happens and suggest freeing space or using linked files.

### 7. Library Maintenance

**Find duplicates (same DOI):**
1. Fetch all journal articles: `curl .../items?limit=100&itemType=journalArticle`
2. Group by DOI (case-insensitive, strip prefix)
3. Report groups with count > 1
4. Ask user before deleting

**Find near-duplicates (same title):**
1. Fetch items, normalize titles (lowercase, strip punctuation, trim whitespace)
2. Report pairs with high similarity
3. Show side-by-side details, let user decide

**Delete items:**
```
mcp__zotero__delete_items(item_keys=["<KEY_1>","<KEY_2>"])
```
Destructive — always confirm before executing. Preview what will be deleted.

**Delete a collection:**
```
mcp__zotero__delete_collection(collection_key="<KEY>")
```

**Orphan detection:**
Find items not in any collection (excluding the root library). Fetch all collection items, subtract from all library items.

## Fallback: Direct Zotero API via curl

When MCP tools are unavailable (e.g., server not running), use curl directly. All Zotero API endpoints share this base:

```bash
API="https://api.zotero.org/users/<USER_ID>"
HEADER="Zotero-API-Key: <API_KEY>"
```

Key endpoints:

| Operation | Method | Endpoint |
|-----------|--------|----------|
| Get items | GET | `/items?limit=N&format=json` |
| Create items | POST | `/items` |
| Update item | PATCH | `/items/<KEY>` |
| Delete items | DELETE | `/items?itemKey=<K1>,<K2>` |
| Get collections | GET | `/collections?limit=N` |
| Collection items | GET | `/collections/<KEY>/items` |
| Add to collection | POST | `/collections/<KEY>/items` |
| Item children | GET | `/items/<KEY>/children` |
| Item tags | GET/POST/DELETE | `/items/<KEY>/tags` |
| Search | GET | `/items?q=<QUERY>` |

For POST/PATCH, set `Content-Type: application/json`. For updates, include `If-Unmodified-Since-Version: <N>` header (get version from item's `version` field).

## Interaction Rules

**Default behavior (no questions needed):**
- Single-item import: just do it, report the result
- Search: return results, let user ask follow-ups
- Add note: attach, report note key
- Auto-categorize: do it, report what was categorized where

**When to confirm (AskUserQuestion):**
- Bulk deletes (any `delete_items` call with >1 item)
- Deleting a non-empty collection
- Import found >=3 duplicates (ask: skip duplicates, add anyway, or abort)
- Destructive metadata overwrites (replacing an existing note)

**When to present options:**
- Import without DOI found >=2 close title matches → show candidates, let user pick
- PDF attachment failed for >=3 items → ask: retry, skip PDFs, or download manually
- Collection auto-categorize is ambiguous (paper matches multiple collections equally) → show matches, let user choose

## Edge Cases

- **Storage quota full:** Metadata + notes still work. Warn about PDFs. Suggest freeing space at https://www.zotero.org/settings/storage.
- **DOI returns wrong item type:** Zotero auto-detects type. If wrong (e.g., `webpage` instead of `journalArticle`), update manually via PATCH.
- **Very large notes (>500KB):** Zotero has no hard limit, but large notes slow the UI. For very long summaries, truncate to the first 200 lines and add "... [full summary in local file: <path>]".
- **API rate limiting:** Zotero API has no documented rate limit, but batch responsibly. For 50+ operations, add 100ms delays between calls.
- **Concurrent modification:** Always use the latest `version` when updating. If a 412 Precondition Failed response occurs, re-fetch and retry.
