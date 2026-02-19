-- 007_add_embeddings.sql
-- Optional embeddings table (1:1 with documents). Vector stored as TEXT (JSON array of floats).
-- See docs/decisions/0010-embeddings-vector-storage-text.md.

CREATE TABLE IF NOT EXISTS embeddings (
  document_id TEXT PRIMARY KEY,
  vector TEXT NOT NULL,
  model_version TEXT,
  created_at INTEGER,
  FOREIGN KEY (document_id) REFERENCES documents(id) ON DELETE CASCADE
);
