-- 002_add_documents_and_pages.sql
-- Introduce core tables for documents and pages.
-- documents.place_id references places, so create places first.

CREATE TABLE IF NOT EXISTS places (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL UNIQUE,
  description TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

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
  id TEXT PRIMARY KEY,
  document_id TEXT NOT NULL,
  page_number INTEGER NOT NULL,
  raw_text TEXT,
  processed_text TEXT,
  ocr_confidence REAL,
  FOREIGN KEY (document_id) REFERENCES documents(id) ON DELETE CASCADE,
  UNIQUE (document_id, page_number)
);

CREATE INDEX idx_documents_status ON documents(status);
CREATE INDEX idx_documents_place_id ON documents(place_id);
CREATE INDEX idx_documents_created_at_status
  ON documents(created_at, status);

CREATE INDEX idx_pages_document_id ON pages(document_id);

