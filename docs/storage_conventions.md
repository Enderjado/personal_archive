## SQLite Storage Conventions

This document defines the **global SQLite schema conventions** for the project. It is the single source of truth for how IDs, timestamps, enums, booleans, and foreign keys are represented in the database.

All schema design, migrations, and repository implementations must follow these rules.

---

### 1. ID Strategy

- **Type & storage**
  - All primary keys are UUIDs stored in `TEXT` columns (e.g., `id TEXT PRIMARY KEY`).
  - Foreign keys always reference these `id` columns (`..._id TEXT NOT NULL REFERENCES other_table(id)` where appropriate).
- **Generation**
  - UUIDs are generated in the **application/domain layer**, not inside SQLite.
  - IDs are immutable once assigned.

---

### 2. Timestamps

- **Representation**
  - All timestamps are stored as `INTEGER` **Unix epoch milliseconds in UTC**.
  - Examples: `created_at INTEGER NOT NULL`, `updated_at INTEGER NOT NULL`, `applied_at INTEGER NOT NULL`.
- **Semantics**
  - Timestamps are written by the application layer at the moment of the logical event (e.g., document creation, migration application), not by ad‑hoc SQL functions.
  - All time calculations and formatting in higher layers assume UTC and convert to local time only at presentation/UI boundaries.

---

### 3. Enums & Status Values

- **General enum representation**
  - All enums are stored as `TEXT` columns.
  - Allowed values must be documented in this section or in the table definition section of the Phase 1 schema doc.
- **Document status**
  - `documents.status` is a `TEXT NOT NULL` column.
  - Allowed values:
    - `imported`
    - `processing`
    - `completed`
    - `failed`
  - Status transitions are enforced in the application/domain layer (e.g., a simple state machine), not via database triggers.

When new enum‑like columns are added (e.g., additional status fields or types), they must:

1. Use `TEXT` columns.
2. Have their allowed values documented here or in an explicit table‑level section.

---

### 4. Booleans

- **Representation**
  - Booleans are represented as `INTEGER` with:
    - `0` = `false`
    - `1` = `true`
- **Usage**
  - Column names should make intent obvious (e.g., `is_active`, `is_deleted`, `is_primary`).
  - Default values should be explicit (`DEFAULT 0` or `DEFAULT 1`) where sensible.

---

### 5. Foreign Keys & Cascading Rules

- **Global enforcement**
  - Every SQLite connection **must** enable foreign key enforcement:
    - `PRAGMA foreign_keys = ON;`
  - Migrations must assume that foreign key checks are active.

- **Default patterns**
  - Parent → strictly owned children (e.g., `documents` → `pages`, `summaries`, `document_keywords`, `embeddings`, FTS/index rows):
    - Use `ON DELETE CASCADE`.
  - Parent → reusable lookup entities (e.g., `places`, `keywords`):
    - Prefer restrictive behavior to avoid accidental data loss.

- **Concrete rules for Phase 1 core tables**
  - `pages.document_id` → `documents.id`:
    - `ON DELETE CASCADE`
  - `summaries.document_id` → `documents.id`:
    - `ON DELETE CASCADE`
  - `document_keywords.document_id` → `documents.id`:
    - `ON DELETE CASCADE`
  - `embeddings.document_id` → `documents.id`:
    - `ON DELETE CASCADE`
  - `documents.place_id` → `places.id`:
    - `ON DELETE RESTRICT` (or equivalent) – a `place` cannot be deleted while referenced by any document.
  - `document_keywords.keyword_id` → `keywords.id`:
    - `ON DELETE CASCADE` – deleting a keyword removes its document associations but not the documents themselves.

Any new foreign keys introduced in later phases should explicitly choose between:

- `ON DELETE CASCADE` for strictly owned child records that should never outlive their parent, or
- `ON DELETE RESTRICT` / `NO ACTION` when deletion of the parent must be a deliberate, higher‑level operation (often preceded by reassignment or cleanup).

The rationale for non‑obvious choices should be captured either here or in an Architecture Decision Record under `docs/decisions/`.

---

### 6. Migration Files & Versioning

- **Migration metadata table**
  - A dedicated `schema_migrations` table tracks which migrations have been applied:
    - `id` – `INTEGER PRIMARY KEY AUTOINCREMENT`
    - `name` – `TEXT NOT NULL` (e.g., `001_init_core_schema`)
    - `applied_at` – `INTEGER NOT NULL` (Unix epoch milliseconds in UTC)
- **Storage location**
  - Migration definitions are stored as `.sql` files under `assets/sql/migrations/`.
  - Filenames start with a zero‑padded numeric prefix followed by a descriptive name, e.g.:
    - `001_init_core_schema.sql`
    - `002_add_documents_and_pages.sql`
- **Ordering & idempotence**
  - Migrations are applied in **lexicographical filename order**, which matches numeric prefix order.
  - Each migration is applied at most once; applied migrations are recorded in `schema_migrations` by `name`.
  - Migration runners must assume foreign keys are enabled and wrap each migration in a transaction.

- **Implemented migrations** (current schema under `assets/sql/migrations/`)
  - **`001_init_core_schema.sql`** – No-op; the migration runner creates the `schema_migrations` table itself.
  - **`002_add_documents_and_pages.sql`** – Creates:
    - `places` (created first so `documents.place_id` can reference it): `id`, `name` NOT NULL UNIQUE, `description`, `created_at`, `updated_at`.
    - `documents`: `id`, `title`, `file_path`, `status`, `confidence_score`, `place_id` (FK → `places.id` ON DELETE RESTRICT), `created_at`, `updated_at`.
    - `pages`: `id`, `document_id` (FK → `documents.id` ON DELETE CASCADE), `page_number`, `raw_text`, `processed_text`, `ocr_confidence`; UNIQUE `(document_id, page_number)`.
    - Indices: `idx_documents_status`, `idx_documents_place_id`, `idx_documents_created_at_status`, `idx_pages_document_id`.

