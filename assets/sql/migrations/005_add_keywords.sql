-- 005_add_keywords.sql
-- Add keywords table with unique (value, type) and indices.

CREATE TABLE IF NOT EXISTS keywords (
  id TEXT PRIMARY KEY,
  value TEXT NOT NULL,
  type TEXT NOT NULL,
  global_frequency INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL,
  UNIQUE (value, type)
);

CREATE INDEX idx_keywords_value ON keywords(value);
CREATE INDEX idx_keywords_type ON keywords(type);
