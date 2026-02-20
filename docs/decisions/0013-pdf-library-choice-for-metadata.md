# PDF library choice for metadata extraction

Date: 2026-02-19

Status: Accepted

## Context

Phase 2 import needs reliable PDF metadata extraction (primarily page count) before creating `Page` rows. The choice must fit local-first operation, work on macOS and Windows targets, and stay behind the `PdfMetadataReader` abstraction so the pipeline remains replaceable.

The import contract is defined in `docs/pdf_import_pipeline.md`, where page-count validation and page-row creation depend on metadata access.

Related decision: imported file storage root/layout and cleanup semantics are documented in `docs/decisions/0012-file-storage-strategy-for-imported-pdfs.md`.

## Decision

- Use **`pdfx`** as the infrastructure PDF library for Phase 2 metadata extraction.
- Restrict usage in Phase 2 to metadata read operations (page count); no OCR/text extraction is part of this phase.
- Keep library-specific code inside the infrastructure implementation of `PdfMetadataReader`.
- Expose only domain/application-level metadata types and typed errors to the pipeline.

## Consequences

- + Supports desktop-focused local execution path needed for this project’s targets.
- + Provides straightforward page-count access required for import validation and page creation.
- + Keeps parser choice isolated so future migration is possible without changing pipeline contracts.
- - Adds native/plugin dependency surface and platform-specific runtime considerations.
- - Malformed/encrypted PDFs may still fail metadata reads and must be mapped to typed validation/metadata errors.
- - If future requirements need advanced PDF semantics, this decision may need revision in a follow-up ADR.

## Implementation References

- `PdfMetadataReader` / `PdfMetadataReaderImpl`: [lib/infrastructure/pdf/pdf_metadata_reader_impl.dart](lib/infrastructure/pdf/pdf_metadata_reader_impl.dart)
