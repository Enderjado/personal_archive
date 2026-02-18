-- 002_add_documents_and_pages.sql
-- Introduce initial skeleton tables for documents and pages.
-- This migration starts with minimal definitions; later migrations
-- will flesh out all columns, indices, and constraints.

CREATE TABLE documents (
  id TEXT PRIMARY KEY
);

CREATE TABLE pages (
  id TEXT PRIMARY KEY
);

