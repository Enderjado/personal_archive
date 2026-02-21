# 15. PDF Rendering Strategy for OCR

Date: 2026-02-21

Status: Accepted

## Context

To perform OCR on a PDF page, we must first render that page into an image format (bitmap or file) that the `OCREngine` can consume.
We previously selected `pdfx` for metadata extraction (ADR 0013). We need to decide if we continue with `pdfx` for rendering or introduce another library, and how we manage the resulting images (in-memory vs file-based) to align with ADR 0014 (OCR Input Abstraction).

## Decision

We will **reuse `pdfx`** for rendering PDF pages to images.
This keeps the dependency footprint small and reuses the existing infrastructure knowledge.

### Rendering Workflow

1.  **Input**: A `Document` (with file path) and a `Page` (with page index).
2.  **Process**:
    - The `PdfPageRenderer` service opens the PDF using `pdfx`.
    - It requests a structured render of the specific page at a target resolution (defaulting to **300 DPI**, configurable via app settings).
    - `pdfx` returns an in-memory image object (or bytes).
3.  **Output**:
    - The renderer returns an `OcrInput` object (specifically `MemoryOcrInput` containing the byte buffer).
    - If the OCR engine requires a file (e.g. a specific Windows API limitation), the *adapter* for that engine is responsible for writing the bytes to a temporary file, not the renderer.

### Temporary Files

We prefer **in-memory processing** (`MemoryOcrInput`) to avoid excessive I/O and potential cleanup issues with temp files.
However, if an adapter *must* use a file:
- It uses the system temp directory.
- It is responsible for deleting the temp file immediately after the OCR operation completes (`try/finally`).

## Consequences

- **Consistency**: We use a single library (`pdfx`) for both metadata and rendering.
- **Performance**: In-memory transfer to OCR avoids disk round-trips for the common case.
- **Flexibility**: The `OcrInput` abstraction (ADR 0014) allows us to change this later (e.g. if we switch to a CLI-based renderer that produces files) without changing the OCR interface.
- **DPI Handling**: We must ensure 300 DPI (or reasonable equivalent scale factor) is used to ensure good OCR accuracy. Low-res rendering will degrade results.

