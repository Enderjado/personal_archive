Here’s a detailed, professional `data_model.md` draft that complements your `architecture.md` and `pipeline.md`. It defines all entities, relationships, and how data flows through the system in a way that’s clear for other developers and reviewers.

---

# Data Model

This document defines the core data structures and relationships used throughout the system. All models are designed for clarity, consistency, and immutability wherever possible. They form the foundation for the pipeline, storage, and search systems, as described in `pipeline.md`.

---

## Core Entities

### Document

Represents a full imported document, either PDF or other supported formats.

| Field             | Type     | Description                                     |
| ----------------- | -------- | ----------------------------------------------- |
| `id`              | UUID     | Unique identifier                               |
| `title`           | String   | Name of the document                            |
| `filePath`        | String   | Path to stored file                             |
| `status`          | Enum     | `imported`, `processing`, `completed`, `failed` |
| `confidenceScore` | Float    | Aggregate confidence from OCR/LLM results       |
| `createdAt`       | DateTime | Timestamp                                       |
| `updatedAt`       | DateTime | Timestamp                                       |
| `placeId`         | UUID     | Foreign key linking the document to a Place     |

**Notes:**

* Immutable ID ensures references remain consistent.
* Status changes are controlled events in the pipeline.
* In Phase 2 import, `filePath` points to the managed storage path (see `pdf_import_pipeline.md` and ADR `decisions/0012-file-storage-strategy-for-imported-pdfs.md`).

---

### Page

Represents a single page extracted from a document.

| Field           | Type   | Description                |
| --------------- | ------ | -------------------------- |
| `id`            | UUID   | Unique page identifier     |
| `documentId`    | UUID   | Foreign key to Document    |
| `pageNumber`    | Int    | Page order in the document |
| `rawText`       | String | Raw text output from OCR   |
| `processedText` | String | Cleaned and chunked text   |

**Notes:**

* Pages are immutable after creation; only `rawText` and `processedText` are updated during pipeline execution.
* Supports per-page confidence scores if needed for logging.
* In Phase 2 import, one `Page` row is created per PDF page with `pageNumber` set and text fields initially empty.

---

### Summary

Represents an automatically generated summary for a document.

| Field          | Type     | Description                     |
| -------------- | -------- | ------------------------------- |
| `documentId`   | UUID     | Foreign key to Document         |
| `text`         | Text     | Generated summary text          |
| `modelVersion` | String   | Version of LLM used             |
| `createdAt`    | DateTime | Timestamp of summary generation |

**Notes:**

* Summaries are generated deterministically and stored for reproducibility.
* Multiple summaries (e.g., versions) can be supported if needed.

---

### Keyword Entity

It is a normalized, reusable object.

| Field             | Type   | Description                                                             |
| ----------------- | ------ | ----------------------------------------------------------------------- |
| `id`              | UUID   | Unique identifier                                                       |
| `value`           | String | Normalized keyword text, e.g. "bank", "transaction", "invoice"         |
| `type`            | String | Enum-like category: `topic`, `date`, `amount`, `organization`, etc.    |
| `globalFrequency` | Int    | Overall frequency this keyword is assigned to documents                 |
| `createdAt`       | Date   | Creation date                                                           |

**Notes:**

* Keywords are unique by normalized form.
* Multiple documents reference the same keyword.
* Keywords are system-generated but editable later.

---

### DocumentKeyword Relation

Represents the connection between a document and a keyword, storing its weight, context, and metadata for ranking and search purposes.

| Field        | Type   | Description                                                                 |
| ------------ | ------ | --------------------------------------------------------------------------- |
| `id`         | UUID   | Unique identifier for this relation entry                                   |
| `documentId` | UUID   | Foreign key referencing the associated Document                             |
| `keywordId`  | UUID   | Foreign key referencing the associated Keyword                              |
| `weight`     | Float  | Importance of this keyword for the document (0–1 scale)                     |
| `confidence` | Float  | Confidence score of the extraction (0–1)                                    |
| `source`     | String | Optional label indicating how the keyword was generated (e.g. `llm_initial`) |

**Notes:**

* This table implements a **many-to-many relationship** between documents and keywords.
* Multiple documents can reference the same keyword, and a document can have multiple keywords.
* `weight` allows search ranking and relevance scoring, while `confidence` supports filtering or validation.
* `source` provides explainability about how the keyword was generated.
* This structure supports future extensions like positions, semantic embeddings, or hierarchical relationships.

---

### Place

Place is a logical grouping or category (like “Banking”, “University”, “Projects”) under which documents are organized.
Every document belongs to exactly one Place.

| Field         | Type     | Description                                    |
| ------------- | -------- | ---------------------------------------------- |
| `id`          | UUID     | Unique identifier                              |
| `name`        | String   | Name of the place / category (e.g., “Banking”) |
| `description` | String?  | Optional notes about the category              |
| `createdAt`   | DateTime | Timestamp                                      |
| `updatedAt`   | DateTime | Timestamp                                      |


**Notes:**

* Proposed Place from LLM.
* Still selection done by user, as this is the most important step for later finding the document again.

---

### Embedding (Phase 1, optional data)

Represents a semantic vector generated by the LLM for search purposes.

| Field          | Type         | Description                                                                 |
| -------------- | ------------ | --------------------------------------------------------------------------- |
| `documentId`   | UUID         | Primary key and foreign key to `Document` (1:1 relationship)               |
| `vector`       | Array[Float] | Semantic representation of document text (stored as JSON `TEXT` in SQLite) |
| `modelVersion` | String       | Identifier of the embedding model used (e.g. `embed-model-v1`)             |
| `createdAt`    | DateTime     | When this embedding was generated                                          |

**Notes:**

* Implemented in Phase 1 as an optional table: a document may or may not have an embedding row.
* Stored separately from the main text to optimize storage and query performance; see `007_add_embeddings.sql`.

---

## Domain Value Objects (Non-Persisted)

These types are used within the application domain and pipeline but are not stored directly as tables.

### OcrInput

Abstract wrapper for image data passed to the OCR engine (ADR 0014).

| Implementation   | Description                                                                     |
| ---------------- | ------------------------------------------------------------------------------- |
| `FileOcrInput`   | Wraps a file path to an image on disk.                                          |
| `MemoryOcrInput` | Wraps in-memory image bytes (`Uint8List`) and metadata (width, height, format). |

### OcrPageResult

The result of an OCR operation on a single page.

| Field        | Type   | Description                                                         |
| ------------ | ------ | ------------------------------------------------------------------- |
| `text`       | String | The raw text extracted from the page.                               |
| `confidence` | Float  | (Optional) Confidence score 0.0-1.0.                                |
| `blocks`     | List   | (Optional) Detailed layout blocks if needed for advanced processing.|

---

## Relationships

This can be best shown in the following Entity Relationship Diagram:

![](assets/Data%20Model%20ER%20Visualization.png)

### Core Relationships

* **Document to Page (1:N):** A single document is partitioned into multiple sequential pages.

* **Document to Summary (1:1):** Each document has a singular text summary.

* **Document to Place (N:1):** Multiple documents can be associated with a specific geographic or logical location.

* **Document to Keyword (M:N):** Handled via the DocumentKeywordRelation join table, allowing documents to have multiple tags and keywords to appear across multiple documents.

* **Document to Embedding (1:1):** OPTIONAL Each document can have a high-dimensional vector representation for search.

Full-text document search in Phase 1 is implemented via a separate SQLite FTS5 virtual table `documents_fts` that indexes document titles, page text, summaries, and keyword values; see `storage_conventions.md` § 7 and the FTS ADR for details.

---

## Principles

* **Immutability:** Core IDs and relationships never change. Data can be updated only through controlled pipeline events.
* **Traceability:** Every entity is linked to its source (document and page) for reproducibility.
* **Normalization:** Data is normalized for storage efficiency but denormalized in queries for fast retrieval if needed.
* **Extendability:** New entities or metadata can be added without breaking existing relationships or pipeline logic.

---

This data model ensures that every document processed is fully traceable, searchable, and structured for maximum clarity. It forms the foundation for the pipelines, storage, and search systems, and ensures the system remains robust and maintainable.

For Phase 2 import-specific behavior (validation, file storage, pipeline steps, and interface boundaries), see `pdf_import_pipeline.md`.
