# Embeddings vector storage: TEXT (JSON) for Phase 1

Date: 2026-02-19

Status: Accepted

## Context

The optional `embeddings` table stores a semantic vector per document (1:1). The vector is an array of floats. We need a concrete storage format in SQLite: **TEXT** (e.g. JSON array) or **BLOB** (binary).

## Decision

Store the vector as **TEXT** containing a JSON array of floats (e.g. `"[0.1,-0.2,...]"`). Use this for Phase 1 and until we have a clear need for a different format.

## Trade-offs

**TEXT / JSON**

- Simple to implement and debug; easy to inspect in SQLite tools.
- Sufficient for moderate numbers of documents and typical embedding dimensions.
- No extra serialization layer; parse with standard JSON in application code.

**BLOB (alternative)**

- Denser storage and potentially faster for very large or binary vector formats.
- Better if we later adopt a fixed-size binary format or native vector extensions.
- Requires a defined binary layout and (de)serialization.

We can introduce a follow-up migration to change the column type if we outgrow TEXT/JSON (e.g. move to BLOB or a dedicated vector extension).
