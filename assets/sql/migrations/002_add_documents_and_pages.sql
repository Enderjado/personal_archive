-- 002_add_documents_and_pages.sql
-- Introduce core tables for documents and pages.
-- Later migrations may extend these tables, but this file is
-- responsible for the initial `documents` and `pages` structures.

CREATE TABLE documents (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  file_path TEXT NOT NULL,
  status TEXT NOT NULL,
  confidence_score REAL,
  place_id TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  FOREIGN KEY (place_id) REFERENCES places(id) ON DELETE RESTRICT
);

CREATE TABLE pages (
  id TEXT PRIMARY KEY
);

