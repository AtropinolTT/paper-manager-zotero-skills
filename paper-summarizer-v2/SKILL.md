---
name: paper-summarizer-v2
description: Summarize academic papers from URLs, DOIs, PMIDs, or arXiv IDs into structured Markdown notes. Use this skill whenever the user wants to summarize papers, survey literature, read academic papers, or do literature review. Triggers on: paper URLs (arxiv.org, nature.com, pubmed, biorxiv, academic.oup.com, etc.), DOI/PMID/arXiv IDs, PDF files, paper summary, literature review, or pasted paper links. Supports single-paper and multi-paper (individual or comparative) modes, including latest top conference papers. Default output language is Chinese; English on request. This is the improved version with bash-based API retrieval and optimized search term strategies.
version: 2.1.0
author: Claude Code Community
license: MIT
tags: [academic, papers, summarization, literature-review, research]
---

# Paper Summarizer v2

Summarize academic papers into structured, accessible Markdown notes with key figures when available. Handle single papers, multiple papers (individual or comparative), and large-scale literature surveys. **Uses bash-based API calls (curl) for all web retrieval — no WebFetch or WebSearch tools.**

## Interaction Rules

**Core principle**: Only force questions when there is a genuine branching choice. Use sensible defaults for everything else. The user can override any default by explicitly stating their preference in the activation message.

### Defaults (no question needed)

| Setting | Default | Override via activation message |
|---------|---------|-------------------------------|
| Language | Chinese (中文) | "in English" / "用英文" |
| Output directory | `paper-summarizer/` in project root | "save to ~/papers/" / "输出到xxx" |
| HTML report | Not generated | User must explicitly opt in via question |
| Output mode (1 paper) | Single summary | N/A — only one mode exists |

### When to Force Questions

Only **two** scenarios trigger mandatory `AskUserQuestion`:

#### Scenario A: Multiple papers (≥2)

User provided ≥2 paper identifiers → ask about output mode and HTML report generation.

```
AskUserQuestion({
  questions: [{
    question: "Detected N papers. How would you like to summarize them?",
    header: "Output Mode",
    options: [
      { label: "Individual summaries", description: "One .md file per paper" },
      { label: "Comparative analysis", description: "Additional comparison doc with timeline, technical routes, difference table" },
      { label: "Both", description: "Individual summaries first, then comparative analysis" }
    ],
    multiSelect: false
  }, {
    question: "Generate a browser-viewable HTML report with embedded figures?",
    header: "HTML Report",
    options: [
      { label: "No", description: "Generate .md files only" },
      { label: "Yes, generate HTML", description: "Also produce a standalone HTML report with rendered markdown and figures" }
    ],
    multiSelect: false
  }]
})
```

Skip the output mode question if user already said "individual" / "comparative" / "both" / "逐篇" / "对比" in the activation message. The HTML question remains unless explicitly addressed.

#### Scenario B: PDF provided

User provided a PDF file → ask about figure extraction and HTML report generation.

```
AskUserQuestion({
  questions: [{
    question: "Should figures be extracted from the PDF?",
    header: "Figures",
    options: [
      { label: "Extract figures", description: "Use pdftoppm/pdfimages to extract key figures from the PDF" },
      { label: "Text only", description: "Skip figure extraction, use text descriptions" }
    ],
    multiSelect: false
  }, {
    question: "Generate a browser-viewable HTML report with embedded figures?",
    header: "HTML Report",
    options: [
      { label: "No", description: "Generate .md files only" },
      { label: "Yes, generate HTML", description: "Produce a standalone HTML report (supports embedding extracted figures)" }
    ],
    multiSelect: false
  }]
})
```

Skip the figure question if user already said "extract figures" / "no figures" / "提取图片" / "不用图片" in the activation message.

### No-Question Fast Path

**Single paper, no PDF → no questions at all.** Proceed directly with:
- Language: Chinese (unless user explicitly said "English" / "英文" in activation)
- Directory: `paper-summarizer/` in project root (unless user gave a path)
- HTML report: not generated (unless user explicitly said "generate html" / "生成html")

### Wait for Reply After Asking

After using `AskUserQuestion`, **stop all subsequent operations**. Wait for the user's selections before continuing. Do NOT start retrieval or summarization in parallel with the question.

---

## Workflow

### Step 1: Route to Fast Path or Question Path

**Before any retrieval, determine the path.**

1. Extract all paper identifiers from the activation message (URL/DOI/PMID/arXiv ID/PDF path).
2. Count papers. Note whether any PDF files are present.
3. Check if user explicitly overrode any defaults in the activation message (language, directory, html).

#### Decision matrix:

| Papers | Has PDF? | Action |
|--------|----------|--------|
| 1 | No | **Fast path** — no questions, use defaults, go to Step 2 |
| 1 | Yes | **Scenario B** — ask figures + HTML report |
| ≥2 | No | **Scenario A** — ask output mode + HTML report |
| ≥2 | Yes | **Both scenarios** — ask output mode + figures + HTML report (max 3 questions, single AskUserQuestion call) |

#### Explicit overrides (check activation message):

- User said "English" / "英文" → use English regardless of default
- User said path like "~/papers/" / "save to xxx" / "输出到xxx" → use that directory
- User said "individual" / "comparative" / "both" / "逐篇" / "对比" → skip output mode question
- User said "extract figures" / "no figures" / "提取图片" / "不用图片" → skip figures question
- User said "generate html" / "no html" / "生成html" / "不生成html" → skip HTML report question

### Step 2: Set Directory and Language

Use the resolved values from Step 1:
- **Directory**: user-specified path, or `paper-summarizer/` in project root
- **Language**: user-specified, or Chinese (default)
- Create `assets/` subdirectory
- File naming: `{FirstAuthorLastName}_{Year}_{ShortTitle}.md` for individual papers; `comparison_{Topic}.md` for comparative analysis

### Step 3: Parallel Execution for Multiple Papers

**When summarizing ≥2 papers in individual mode, use parallel subagents for maximum efficiency.**

For each paper, spawn a subagent with explicit workflow instructions:

```
Execute the following task using the paper-summarizer-v2 skill:
1. Skill path: /home/tt-wsl-ubuntu/.claude/skills/paper-summarizer-v2
2. Task: Summarize paper identifier [PMID/DOI/arXiv/Title] and save to [output file path]
3. Workflow to follow:
   a. Try PubMed API first (esearch → esummary → efetch). If PMID known, start here.
   b. If PubMed fails after 4-5 attempts: compact your session (/compact) to save context, then try CrossRef API.
   c. If CrossRef fails after 4-5 attempts: compact your session again, then try arXiv API.
   d. If arXiv also fails after 4-5 attempts: STOP and report to user that the paper cannot be found. Ask user to provide the DOI link, PDF file, or correct identifier.
   e. Once you have enough info (title, abstract, authors, year), write summary in the exact template format
   f. Save to the specified output file path
4. IMPORTANT: Do NOT search endlessly. Each API gets 4-5 tries max. If one fails, compact and move to the next.
5. Output language: [Use the language chosen by user in Step 1]
```

Spawn all subagents in the same turn — they run concurrently. Do NOT spawn them sequentially.

**Example for 3 papers:**
```
Agent 1: Summarize PMID 40875799, save to: paper-summarizer/Zhang_2025_GEMORNA.md
Agent 2: Summarize PMID 41069846, save to: paper-summarizer/Liu_2025_UTailoR.md
Agent 3: Summarize PMID 34009265, save to: paper-summarizer/Chu_2021_MDA_GCN_FTG.md
```

Wait for all agents to complete, then proceed to Step 10 for comparative analysis and/or HTML report generation.

### Step 4: Gather Paper Information (Bash-Based Retrieval)

**Single paper OR when parallel agents are not used — gather info manually via bash curl calls.**

**All web access via curl/bash. Never use WebFetch or WebSearch.**

#### Tier 1 — PubMed E-utilities (preferred for biomedical papers)

**Article search by title or keyword:**
```bash
curl -s "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?db=pubmed&term=TITLE+query&retmax=5&retmode=json"
```

**Fetch article details by PMID:**
```bash
curl -s "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esummary.fcgi?db=pubmed&id=PMID&retmode=json"
```

**Fetch full abstract with links:**
```bash
curl -s "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=pubmed&id=PMID&rettype=abstract&retmode=text"
```

#### Tier 2 — arXiv API (for preprint/conference papers)

**Search by title or keyword:**
```bash
curl -s "https://export.arxiv.org/api/query?search_query=ti:TITLE+AND+au:AUTHOR&start=0&max_results=3&sortBy=relevance&sortOrder=descending"
```

**Fetch paper by arXiv ID:**
```bash
curl -s "https://export.arxiv.org/api/query?id_list=ARXIV_ID"
```

#### Tier 3 — CrossRef API (for DOI resolution and citation info)

**Resolve DOI to metadata:**
```bash
curl -s "https://api.crossref.org/works/DOI" -H "Accept: application/json"
```

**Search by title:**
```bash
curl -s "https://api.crossref.org/works?query.title=TITLE&rows=5" -H "Accept: application/json"
```

#### Tier 4 — Semantic Scholar API (supplementary data)

**Search by title:**
```bash
curl -s "https://api.semanticscholar.org/graph/v1/paper/search?query=QUERY&fields=title,authors,abstract,year,venue,journal,openAccessPdf,externalIds&limit=5" -H "x-api-key: SEMANTIC_SCHOLAR_API_KEY"
```

**Fetch by DOI:**
```bash
curl -s "https://api.semanticscholar.org/graph/v1/paper/DOI:DOI?fields=title,authors,abstract,year,venue,journal,openAccessPdf,externalIds" -H "x-api-key: SEMANTIC_SCHOLAR_API_KEY"
```

### Step 5: Optimized Search Term Construction

**Core principle: Start narrow (title-based), then expand if needed.**

#### For DOI/PMID/arXiv ID (known ID):
1. Try CrossRef for DOI → get title, authors, journal
2. Try PubMed for PMID → get abstract, MeSH terms
3. Try arXiv for arXiv ID → get abstract, categories

#### For title-based search (no ID):
```
# Step 1: Exact title search (highest priority)
# Use quotes for exact matching

# Step 2: Author + year search (if title yields no results)
# Format: "FirstAuthorLastName" + "year" + "key_word"

# Step 3: Keyword expansion (if still no results)
# Extract 2-3 key nouns from title, combine with domain terms
```

**Query templates by paper type:**

| Paper Type | Search Strategy | Example Query |
|------------|-----------------|---------------|
| BCR/Antibody | Author + year + key domain term | `"Setliff" 2019 LIBRA-seq B cell` |
| Machine Learning | Title exact → title keywords | `"attention is all you need"` |
| Conference paper | Title + venue + year | `"transformer" ICLR 2020` |
| Multi-author | First author + year + title word | `"Hinton" 2021 contrastive learning` |

**Common failure modes and fallbacks:**

| Failure | Fallback |
|---------|----------|
| No results for exact title | Remove stop words, search author + year |
| Too many irrelevant results | Add journal/venue name as filter |
| Abstract only (no full text) | Use search results to fill in methods details |
| Paper not in PubMed | Try arXiv, then CrossRef, then direct URL |

### Step 6: Conference Paper Detection and Handling

A paper is likely a conference paper if:
- Search results show venue = "NeurIPS", "ICML", "ICLR", "AAAI", "ACL", "EMNLP", "CVPR", "ICCV", "ECCV", "KDD", "WWW", "RecSys"
- arXiv category is cs.* (cs.LG, cs.CL, cs.CV, etc.)
- DOI shows conference proceedings format

**For conference papers:**
- Extract publication venue and year
- Note if it's a poster, spotlight, or oral
- Check if there's a longer journal version (some papers are conference + journal)
- Use "conference" instead of "journal" in the summary

### Step 7: Handle Figures (Best-Effort, with Text Fallback)

**Priority order for figure extraction:**
1. **Local PDF**: If the user provides a PDF file, use `pdftoppm` to render key pages, or `pdfimages` to extract embedded figures. Save to `assets/`.
2. **Open access PDF link**: If CrossRef/Semantic Scholar returns an openAccessPdf URL, use curl to download and extract.
3. **Neither works (most common)**: Write a detailed text description of the figure instead.

**Text fallback format — use this when images cannot be extracted:**
```markdown
> **Fig. 1 Overview (text description — figure could not be extracted)**: {Concise description of what the figure shows — workflow steps, key comparisons, schematic structure, etc.}
```

**Which figures to describe:**
1. **Overview figure** (Figure 1 or equivalent): The schematic explaining the paper's core idea or workflow.
2. **Key result figures** (1-2 most important): Figures showing main quantitative results or representative examples.

Only describe figures you have sufficient information about from the abstract or search results. If you cannot confidently describe a figure, skip it rather than guessing.

### Step 8: Read and Extract Key Information

From the gathered sources (abstract + search results + any accessible full text), identify:
- Publication status: journal/conference, date, DOI. If preprint, find earliest public date (arXiv/bioRxiv submission).
- Key quantitative results (numbers, metrics, comparisons).
- Method details: model architecture, dataset size, evaluation pipeline.
- Representative figures and what they show.

### Step 9: Write the Summary

Use this exact template for each paper:

```markdown
# {Paper Title}

**One-sentence summary**: {One-sentence summary in plain language. Include publication status or earliest public date.}

---

> **Fig. 1 Overview**: {Describe the overview figure if known. Otherwise omit this block.}

---

**Motivation**
1. {Motivation point 1}
2. {Motivation point 2}

**Innovations** (no more than 3)
1. {Innovation 1}
2. {Innovation 2}
3. {Innovation 3}

**Methods**
{One continuous paragraph describing the method in accessible language. Use bullet points (unordered) only when the method has distinct stages that benefit from visual separation. Avoid over-segmenting.}

**Results**
- {Key result 1}
- {Key result 2}
- {Key result 3}

> **Key Result Figure Overview**: {Describe the key result figure if known. Otherwise omit.}

**Limitations**
1. {Limitation 1}
2. {Limitation 2}
```

If images were successfully extracted, replace the text description blocks with `![Fig. X: Description](assets/{PaperSlug}_FigX.png)`.

### Step 10: Post-Summary Actions

**Comparative analysis** (if user chose "Comparative" or "Both" in Scenario A):
Produce an additional `comparison_{Topic}.md` document with:
1. **Timeline**: Papers ordered chronologically, showing how the field evolved.
2. **Technical Route**: Papers grouped by methodology lineage (e.g., "CNN-based approaches", "Transformer/PLM methods", "Multi-modal generative models").
3. **Key Differences Table**: A table comparing core metrics, datasets, methods, and conclusions across papers.

**HTML report generation** (if user chose "Yes, generate HTML" in Scenario A or B):
Generate a standalone `paper-summarizer/report.html` file from scratch:
- Use `marked.js` (CDN) to render all .md summaries as HTML in the browser.
- Embed extracted figures from `assets/` as `<img>` tags with appropriate captions.
- Include a sidebar navigation listing all summarized papers.
- The report is fully self-contained — works offline except for the CDN script tag.
- Template structure:
  ```html
  <!DOCTYPE html>
  <html lang="en">
  <head><meta charset="UTF-8"><title>Paper Summaries</title>
  <script src="https://cdn.jsdelivr.net/npm/marked/marked.min.js"></script>
  </head>
  <body>
    <nav><!-- Paper list sidebar --></nav>
    <main><!-- Rendered markdown content --></main>
  </body>
  </html>
  ```
- Hardcode all markdown content into a JavaScript object so no file server is needed.
- If no figures were extracted, the report still works — just without images.

---

## Guidelines

- **Depth over breadth**: Read the actual paper content (abstract + methods + results at minimum). Do not summarize from title alone.
- **Figures are best-effort**: Extract when possible; describe in text when not. Never block on figure extraction.
- **Numbers matter**: Always capture representative quantitative results (accuracy, sample size, key metrics).
- **Accessibility**: The one-sentence summary should be understandable to a non-specialist in the specific subfield.
- **Honesty about limitations**: Note dataset biases, small sample sizes, lack of experimental validation, or other weaknesses.
- **Publication verification**: Check publication status via DOI lookup or journal/conference page. Distinguish "published in X" from "preprint as of Y date".
- **All retrieval via bash**: Use curl to call APIs. Never use WebFetch or WebSearch tools.
- **Respect user choices from Step 1**: Use the language, directory, and output mode selected by the user throughout.

## Dependencies

| Tool | Purpose | Required? |
|------|---------|-----------|
| `curl` | All web API calls (PubMed, arXiv, CrossRef, Semantic Scholar) | Required |
| `mcp__pubmed__*` | PubMed structured metadata — optional alternative to curl | Optional |
| `pdftoppm` / `pdfimages` | Figure extraction from local PDF files (poppler-utils) | Optional |
| `pandoc` | Text extraction from local PDF/DOCX files | Optional |
| `pdf` skill | Full-text extraction from local PDFs | Optional |

**No WebFetch or WebSearch — all retrieval via bash curl calls.**

## Example Queries That Trigger This Skill

- "Summarize this paper: https://www.nature.com/articles/s41586-019-0879-y"
- "Help me summarize these three papers: 10.1016/j.cell.2019.11.003, arXiv:2103.14030, PMC7158953"
- "Literature survey: latest top-conference papers on B-cell receptor evolution trees"
- "Summarize this PDF: ~/Downloads/antibody-forests.pdf"
- "summary: 10.1038/s41586-022-05672-3"
- "Latest AI papers from 2024"
