-- 005_add_document_keywords.sql
-- Add document_keywords join table (many-to-many documents <-> keywords).

CREATE TABLE document_keywords (
  id TEXT PRIMARY KEY,
  document_id TEXT NOT NULL,
  keyword_id TEXT NOT NULL,
  weight REAL NOT NULL,
  confidence REAL NOT NULL,
  source TEXT,
  FOREIGN KEY (document_id) REFERENCES documents(id) ON DELETE CASCADE,
  FOREIGN KEY (keyword_id) REFERENCES keywords(id) ON DELETE CASCADE,
  UNIQUE (document_id, keyword_id)
);

CREATE INDEX idx_document_keywords_document_id ON document_keywords(document_id);
CREATE INDEX idx_document_keywords_keyword_id ON document_keywords(keyword_id);
