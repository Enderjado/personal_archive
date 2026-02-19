-- 003_add_summaries.sql
-- Add summaries table (1:1 with documents).

CREATE TABLE summaries (
  document_id TEXT PRIMARY KEY,
  text TEXT NOT NULL,
  model_version TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  FOREIGN KEY (document_id) REFERENCES documents(id) ON DELETE CASCADE
);
