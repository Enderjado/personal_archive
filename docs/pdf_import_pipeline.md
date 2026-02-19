# Phase 2: PDF Import Pipeline (Implementation Specification)

This document defines the public Phase 2 implementation specification for the PDF input pipeline. It is the canonical reference for implementers and reviewers who do not have access to private preparation material.

It complements the high-level pipeline in `pipeline.md` and aligns with `architecture.md`, `data_model.md`, and `storage_conventions.md`.

---

## Objectives

Phase 2 establishes a reliable import foundation that:

1. accepts a user-selected PDF,
2. validates it before persistence,
3. stores it in app-managed file storage,
4. creates `Document` and `Page` records with initial status `imported`.

The output of this phase is a correctly imported, internally tracked document ready for downstream processing stages.

---

## Scope

### In Scope

- PDF import contract and orchestration responsibilities.
- Input validation requirements before copy and database writes.
- File storage strategy for imported PDFs.
- Initial persistence flow for `Document` and `Page` entities.
- Error handling and cleanup semantics for import failures.

### Out of Scope

- OCR execution and OCR quality handling.
- LLM summarization, keyword extraction, and place classification.
- UI/UX behavior beyond initiating import.
- Search ranking and retrieval behavior beyond required import sync points.

---

## Terminology

- **Import source path**: Original user-selected file location.
- **Managed PDF path**: Destination path controlled by application storage conventions.
- **Validation error**: Rejection before file copy or DB writes.
- **Import failure**: Failure during copy or persistence after validation succeeds.

---

## Phase 2 Sections (Detailed in Subsequent Commits)

The following sections are intentionally scaffolded in this first docs commit and will be fully specified in follow-up commits:

1. File storage strategy (root, naming/layout, copy vs move policy).
2. Validation rules and error representation.
3. Ordered pipeline sequence and side-effect boundaries.
4. Interface contracts (`DocumentPipeline`, `DocumentFileStorage`, `PdfMetadataReader`).
5. Error handling and cleanup behavior (no orphan files/records).
6. Cross-links to ADRs for discrete architecture decisions.

---

## Related Documents

- `pipeline.md` (high-level end-to-end pipeline)
- `architecture.md` (layer boundaries and responsibilities)
- `data_model.md` (entity semantics for `Document` and `Page`)
- `storage_conventions.md` (SQLite and storage conventions)
- `decisions/` (ADRs for file storage strategy and PDF metadata library choice)
