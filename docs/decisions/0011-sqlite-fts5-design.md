# SQLite FTS5 full-text search design

Date: 2026-02-19

Status: Accepted

## Context

The project needs full-text search over documents using SQLite FTS5. We had to decide indexing level (document vs page), which fields to index, and how to keep FTS in sync with base tables.

## Decision

- **Indexing level:** Document-level (one FTS row per document).
- **Schema:** Single FTS5 table `documents_fts`; indexed content: title, concatenated page text, summary, keywords (see canonical schema in `docs/storage_conventions.md` § Full-Text Search (FTS5)).
- **Synchronization:** Application-driven (app updates FTS when indexed data changes; no triggers). Chosen for explicitness and testability; trigger-based sync was rejected for Phase 1.

Full design, field sources, and example queries (e.g. search by text and filter by place or date) are in **`docs/storage_conventions.md` § 7. Full-Text Search (FTS5)**.
