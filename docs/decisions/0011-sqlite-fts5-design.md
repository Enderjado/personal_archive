# SQLite FTS5 full-text search design

Date: 2026-02-19

Status: Accepted

## Context

The project needs full-text search over documents using SQLite FTS5. We must decide the indexing level (document vs page), which fields to index, and how to keep the FTS table(s) in sync with the base tables. Without a clear design, search features risk inconsistency or inefficiency.

## Decision

### Indexing level: document-level

We use **document-level** indexing: one FTS row per document. Page-level indexing (one row per page) is not used in Phase 1.

**Rationale:** Document-level matches the primary use case (“find documents that match this text”) and keeps the schema simple. A single `documents_fts` table is easier to reason about and to sync. Page-level indexing can be added later if we need “jump to page” or per-page search.

### Schema: single FTS table `documents_fts`

One FTS5 virtual table, **`documents_fts`**, with one row per document. Content is built from:

| Logical content        | Source tables/columns                          |
|------------------------|-------------------------------------------------|
| Document title         | `documents.title`                              |
| Processed page text    | Concatenation of `pages.text` for the document |
| Summary text           | `summaries.text` (if present)                   |
| Keyword values         | `keywords.value` via `document_keywords`       |

These are combined into one or more FTS columns so that a single query can match across title, body, summary, and keywords. Exact column layout (one concatenated column vs separate FTS columns) is defined in the implementation issue; the important point is that all of the above are searchable.

The FTS table will store `document_id` (or equivalent) so that search results can be joined back to `documents` and filtered by place, date, status, etc.

### Synchronization strategy: application-driven

FTS is kept in sync by the **application layer**, not by SQLite triggers. When documents, pages, summaries, or document_keywords change, the application calls into a search/index component to update or rebuild the relevant FTS row(s).

**Trade-offs:**

- **Application-driven (chosen):** Explicit and testable; we can assert on when and how FTS is updated. Easier to reason about in tests and when adding new write paths. Requires that every code path that mutates indexed data calls the update logic.
- **Trigger-based (alternative):** Automatic sync on every insert/update/delete; no risk of forgetting to update FTS. Harder to debug and to test in isolation; triggers are less visible from application code.

Implementation details (migrations, exact trigger vs repository calls) are left to the follow-up issue that creates the FTS tables and wiring.
