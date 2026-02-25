# Processed text storage for Intelligence (per-page, document-level aggregation)

Date: 2026-02-25

Status: Accepted

## Context

Phase 4 (Intelligence) introduces multiple LLM-backed analyses (summaries, keywords, places, future classifiers) that operate on cleaned, normalized text rather than raw OCR output.

The existing schema already includes:

- `pages.processed_text` (per-page cleaned text).
- A document-level FTS index (`documents_fts`) that concatenates page text (see `storage_conventions.md` § 7 and ADR 0011).
- A document-level `summaries` table and optional `embeddings` table.

We need to clarify whether processed text is a **per-page concept**, a **per-document concept**, or both, and how this interacts with FTS and future Intelligence features.

## Decision

- **Primary unit of processed text is the page:**
  - `pages.processed_text` remains the canonical home for cleaned text.
  - All Intelligence pipelines that need cleaned text read from `pages.processed_text` (falling back to `pages.raw_text` only when necessary).
- **Document-level aggregation is derived, not stored as a separate canonical field:**
  - When needed, the application concatenates `pages.processed_text` in `page_number` order to form a document-level text view.
  - The `documents_fts` table continues to index **aggregated page text**, summaries, and keywords, without introducing a new “processed document text” column in the `documents` table.
- **Schema changes for Phase 4 are minimal:**
  - No new core tables are added for processed text.
  - If auxiliary cache columns or materialized views are introduced later for performance, they are treated as **derived data**, not new sources of truth.

## Consequences

- **Pros**
  - + Keeps the schema simple and aligned with existing Phase 1/2 decisions.
  - + Preserves per-page traceability for debugging and targeted reprocessing.
  - + Avoids duplicating large processed text blobs at both page and document levels.
  - + Integrates cleanly with existing FTS design (document-level indexing derived from page-level text).

- **Cons / Trade-offs**
  - - Some Intelligence operations that conceptually work on “the whole document” must stream or aggregate page text on the fly.
  - - Large documents may require careful batching when concatenating text for LLM input.

- **Implications for future work**
  - Any new Phase 4 repositories or services that need “document text” should depend on:
    - `pages.processed_text` as the canonical source, and
    - a **document-text view helper** that aggregates per-page text in a predictable order.
  - If per-section or per-chunk storage is introduced later (e.g., for re-usable semantic chunks), those will layer on top of `pages.processed_text` rather than replacing it.

