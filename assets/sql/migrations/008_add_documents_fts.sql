-- 008_add_documents_fts.sql
-- Add FTS5 virtual table for full-text search over documents.
-- One row per document. Sync is application-driven (see docs/storage_conventions.md § 7).

CREATE VIRTUAL TABLE IF NOT EXISTS documents_fts USING fts5(
  document_id UNINDEXED,
  content
);
