# File storage strategy for imported PDFs

Date: 2026-02-19

Status: Accepted

## Context

Phase 2 requires a deterministic and safe way to persist imported PDFs in local app-managed storage. Import must be independent from the original user-selected path and must avoid orphan files or half-imported persistence on failure.

The public implementation contract for Phase 2 import is defined in `docs/pdf_import_pipeline.md`. Global storage and persistence conventions are defined in `docs/storage_conventions.md`.

Related decision: PDF metadata library selection is documented in `docs/decisions/0013-pdf-library-choice-for-metadata.md`.

## Decision

- Imported PDFs are stored under a configurable application-managed storage root.
- Managed path format is deterministic: `<storageRoot>/<documentId>.pdf`.
- Import uses **copy** from source path to managed path; it does not move, mutate, or delete source files.
- `Document.filePath` persists the managed path, not the original source path.
- Cleanup contract:
  - validation failure: no copy and no DB writes,
  - copy failure: no DB writes,
  - failure after copy and before persistence completion: delete copied managed file (rollback).

## Consequences

- + Import behavior is predictable and independent of external source-file lifecycle.
- + Deterministic naming simplifies lookup, testing, and troubleshooting.
- + Copy policy preserves user files and avoids cross-volume move edge cases.
- + Explicit cleanup semantics prevent orphan managed files and partial import state.
- - Requires storage-root configuration and write-permission validation.
- - May temporarily duplicate disk usage during import.
