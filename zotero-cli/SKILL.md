---
name: zotero-cli
description: Use when the user mentions papers, references, citations, Zotero, literature, bibliography, or needs to search/read/export documents from a Zotero library. Wraps the `zot` CLI (zotero-cli-cc) — local SQLite reads, Zotero Web API writes, PDF text extraction, workspace-based RAG.
---

# Zotero CLI Skill

**`zot`** — Zotero CLI for agent use: CRUD, search, PDF extraction, export, workspace-based RAG. Local SQLite for reads, Zotero Web API for writes.

## Install

```bash
pipx install zotero-cli-cc          # or: uv tool install zotero-cli-cc
zot config init                     # only needed for write ops (Zotero Web API key)
```

Read operations work offline with zero config — `zot` auto-detects the local Zotero data directory (`~/Zotero` on macOS/Linux, `%APPDATA%\Zotero` on Windows). Reads use a read-only SQLite handle, so they work while Zotero.app is running.

If `zot` is not on PATH, stop and tell the user to install it rather than attempting fallbacks.

## Conventions

- **Always use `--json`** when processing results programmatically. (Auto-enabled when stdout is not a TTY; can be placed before or after the subcommand.)
- For exhaustive flags / types / safety tier of any command, run `zot schema <cmd>` (e.g. `zot schema add`) — that is the canonical machine-readable surface.
- **Typed exit codes:** 1 runtime, 2 auth, 3 validation, 4 not-found, 5 network, 6 conflict. Handle these instead of grepping stderr.
- **Item keys** are 8-character alphanumeric strings like `K853PGUG`.

## Routing Rules

| User Intent | Command | Why |
|-------------|---------|-----|
| Search by title/author/tag | `zot --json search "transformer"` | Fast metadata match |
| Read/view a paper | `zot --json read KEY` | Direct lookup |
| List items in a collection | `zot --json list --collection "NLP"` | Local SQLite |
| Export citation | `zot export KEY` | Local data |
| Formatted citation | `zot cite KEY --style apa` | APA / Nature / Vancouver |
| Add by DOI/URL | `zot add --doi "10.1038/..."` | Web API write |
| Batch import DOIs/URLs | `zot add --from-file file.txt` | One per line |
| Update item metadata | `zot update KEY --title/--field` | Web API write |
| Upload attachment | `zot attach KEY --file paper.pdf` | Web API write |
| PDF full text | `zot --json pdf KEY` | Local file access |
| PDF outline (headings) | `zot --json pdf --outline KEY` | Token-efficient before full text |
| PDF section by id | `zot --json pdf --section SECID KEY` | Targeted extraction |
| Find duplicates | `zot --json duplicates` | Local SQLite |
| Recently added items | `zot --json recent --days 7` | Local SQLite |
| Trash management | `zot --json trash list` | Local SQLite |
| Library stats | `zot --json stats` | Local aggregation |
| Open PDF/URL | `zot open KEY` or `zot open --url KEY` | System open |
| Group library access | `zot --library group:123 search "q"` | All commands |
| Curate papers by topic | `zot workspace new <name>` | Local workspace, no API |
| Deep content search (RAG) | `zot workspace query "question" --workspace <name>` | BM25 + optional semantic |

**Rule of thumb:** use `zot search` for quick metadata lookups; use `zot workspace query` for deep content search over a curated set of papers (indexes metadata + PDF fulltext).

---

## Read Operations

### Search & Browse

```bash
zot --json search "transformer attention"
zot --json search "BERT" --collection "NLP"
zot --json list --collection "Machine Learning" --limit 10
zot --json read ITEMKEY
zot --json relate ITEMKEY
```

### Notes & Tags

```bash
zot --json note ITEMKEY
zot note ITEMKEY --add "Key finding: ..."
zot --json tag ITEMKEY
zot tag ITEMKEY --add "important"
zot tag ITEMKEY --remove "to-read"
```

### Citation Export

```bash
zot export ITEMKEY                    # BibTeX (default)
zot export ITEMKEY --format csl-json
zot export ITEMKEY --format ris
zot export ITEMKEY --format json

zot cite ITEMKEY                      # APA (default), copies to clipboard
zot cite ITEMKEY --style nature
zot cite ITEMKEY --style vancouver
```

### Collections

```bash
zot --json collection list
zot --json collection items COLLECTIONKEY
zot collection create "New Project"
zot collection move ITEMKEY COLLECTIONKEY
zot collection rename COLLECTIONKEY "New Name"
zot collection delete COLLECTIONKEY
```

### Duplicates, Recent & Trash

```bash
zot --json duplicates                # DOI + title matching
zot --json duplicates --by title     # Title-only
zot --json recent --days 7
zot --json recent --sort dateModified
zot --json trash list
zot trash restore ITEMKEY
```

### PDF

```bash
zot --json pdf ITEMKEY                  # Full text
zot --json pdf --outline ITEMKEY        # Headings + section ids
zot --json pdf --section SECID ITEMKEY  # One section by id
zot pdf ITEMKEY --annotations           # PDF annotations
zot --json summarize ITEMKEY            # Abstract / short summary
```

> **Token discipline:** before fetching full PDF text on a long document, run `--outline` first to get section ids, then pull only relevant sections with `--section`. Use `wc -m` on the JSON output if you need to estimate size before piping into context.

### Utilities

```bash
zot --json stats
zot open ITEMKEY               # Open PDF in system viewer
zot open --url ITEMKEY         # Open URL/DOI in browser
```

### Group Libraries

```bash
zot --library group:12345 search "query"
zot --library group:12345 list
```

---

## Write Operations (mutating)

```bash
zot add --doi "10.1038/s41586-023-06139-9"
zot add --url "https://arxiv.org/abs/2301.00001"
zot add --from-file dois.txt              # Batch import (one DOI/URL per line)
zot add --pdf paper.pdf                   # Add from local PDF (auto-extract DOI)
zot update ITEMKEY --title "New Title"
zot update ITEMKEY --field volume=42 --field pages=1-10
zot attach ITEMKEY --file supplement.pdf
zot --no-interaction delete ITEMKEY
```

### Agent-safety flags

Every mutating command supports `--dry-run` and `--idempotency-key`:

```bash
# Preview without writing — no Zotero API call
zot add --doi "10.1038/..." --dry-run
zot delete ITEMKEY --dry-run
zot update ITEMKEY --field volume=42 --dry-run

# Idempotency — replay safely after a network blip
zot add --doi "10.1038/..." --idempotency-key abc-123
zot attach ITEMKEY --file x.pdf --idempotency-key abc-125
zot delete ITEMKEY --yes --idempotency-key abc-126
```

**Rule:** use `--dry-run` first on any unfamiliar write. Pass a unique `--idempotency-key` whenever you might retry.

---

## Workspaces & RAG

Workspaces are local collections of paper references for organizing research by topic. Each workspace stores item keys in a TOML file at `~/.config/zot/workspaces/<name>.toml` — no Zotero API key needed.

```bash
# Create and manage
zot workspace new llm-safety --description "LLM alignment papers"
zot workspace add llm-safety KEY1 KEY2 KEY3
zot workspace remove llm-safety KEY1
zot workspace list
zot workspace show llm-safety
zot workspace delete llm-safety --yes

# Bulk import from collection, tag, or search
zot workspace import llm-safety --collection "Alignment"
zot workspace import llm-safety --tag "safety"
zot workspace import llm-safety --search "RLHF"

# Search within workspace (metadata substring)
zot --json workspace search "reward" --workspace llm-safety

# Export for AI consumption
zot workspace export llm-safety                       # Markdown (default)
zot workspace export llm-safety --format json
zot workspace export llm-safety --format bibtex

# RAG index (BM25 over metadata + PDF text)
zot workspace index llm-safety             # Incremental
zot workspace index llm-safety --force     # Full rebuild — slow

# Query with natural language
zot --json workspace query "reward hacking" --workspace llm-safety --top-k 5

# Retrieval modes (defaults to hybrid if embeddings configured)
zot workspace query "q" --workspace name --mode bm25       # Keyword only
zot workspace query "q" --workspace name --mode semantic   # Embeddings only
zot workspace query "q" --workspace name --mode hybrid     # BM25 + semantic fusion
```

Result chunks have the shape `[title > heading] chunk text...`:

```json
{
  "rank": 1,
  "score": 0.0154,
  "item_key": "B6TZ6TQX",
  "source": "pdf",
  "content": "[Attention Is All You Need > 3.2 Multi-Head Attention] Instead of performing a single attention function..."
}
```

> **Do not** run `zot workspace index --force` without confirming with the user — a full rebuild can take a long time on a large workspace. If a query fails because the index is missing, warn the user and let them choose when to build.

> Semantic retrieval is optional: BM25 always works; for embeddings set `ZOT_EMBEDDING_URL` and `ZOT_EMBEDDING_KEY`.

---

## Global Flags

| Flag | Purpose |
|------|---------|
| `--json` | JSON envelope output (always use programmatically) |
| `--limit N` | Limit results (default: 50) |
| `--detail minimal` | Only key/title/authors/year — saves tokens |
| `--detail full` | Include extra fields |
| `--no-interaction` | Suppress prompts (for automation) |
| `--library group:<id>` | Operate on a group library |
| `--profile NAME` | Use a specific config profile |
| `--verbose` | Verbose/debug output |

---

## Workflow Patterns

### Pattern 1: Find and read a paper

```bash
zot --json search "single cell RNA sequencing"   # 1. Search
zot --json read K853PGUG                         # 2. Metadata
zot --json pdf --outline K853PGUG                # 3a. Section headings
zot --json pdf --section 10 K853PGUG             # 3b. One section (e.g. Results)
zot --json pdf K853PGUG                          # 3c. Full text (only if needed)
```

For long PDFs, prefer outline → section over full text.

### Pattern 2: Deep content search via workspace RAG

```bash
# 1. Create workspace and add papers
zot workspace new drug-resistance --description "Cancer drug resistance"
zot --json search "drug resistance cancer" --limit 20
zot workspace add drug-resistance KEY1 KEY2 KEY3

# 2. Build index (metadata + PDF fulltext)
zot workspace index drug-resistance

# 3. Query with natural language
zot --json workspace query "mechanisms of acquired resistance" \
  --workspace drug-resistance --top-k 5

# 4. For more context around a chunk, pull the surrounding section
zot --json pdf --outline ITEMKEY
zot --json pdf --section SECID ITEMKEY
```

---

## Notes

- Read operations work offline with zero config; write operations need API credentials (`zot config init`).
- PDF extractions are cached automatically per extractor.
- Workspaces are pure local TOML files — no API key needed for basic operations. `workspace index` reads PDFs from Zotero storage.
- Workspace RAG: BM25 always available (zero deps); optional semantic search via `ZOT_EMBEDDING_URL` + `ZOT_EMBEDDING_KEY`.
- Never edit `zotero.sqlite` directly — `zot` only reads from it; all writes go through the Zotero Web API so sync stays consistent.
