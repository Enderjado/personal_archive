# SQLite for document and metadata storage

Date: 2026-02-15

Status: Accepted

## Context

Storage must be local, fast, and support structured queries. Relational design is needed for documents, pages, summaries, keywords, and place relations.

## Decision

Use SQLite as the storage engine. Define a repository layer that hides implementation from domain logic.

## Consequences

- + Lightweight, fast, widely supported
- + Supports relational queries, indexing, and future semantic embeddings
- - Single-user design (no multi-machine sync)
- - Requires careful schema management
