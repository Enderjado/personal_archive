# 14. OCR Input Abstraction

Date: 2026-02-21

Status: Accepted

## Context

The OCR pipeline requires passing image data from a PDF renderer (which converts a specific page of a PDF into an image) to a platform-specific OCR engine (Windows or macOS native APIs).
Different platforms and libraries may prefer different input formats:
- Some native APIs work best with file paths.
- Others might accept in-memory byte buffers (e.g. raw RGBA or encoded JPEG/PNG).
- We want to avoid premature optimization (forcing all to bytes) or unnecessary I/O (forcing all to temp files) if not needed.
- The domain layer `OCREngine` interface must remain platform-agnostics.

## Decision

We will define an abstract `OcrInput` class (or sealed class) in the domain layer that encapsulates the image data source.
It will initially support two subtypes:

1.  `FileOcrInput`: wrappers a file path to an image on disk.
2.  `MemoryOcrInput`: wrappers in-memory image bytes (e.g. `Uint8List`) and metadata (width, height, format).

The `OCREngine` interface will accept `OcrInput`:
```dart
abstract class OCREngine {
  Future<OcrPageResult> processPage(OcrInput input);
}
```

This allows the specific `PdfPageRenderer` implementation to decide the most efficient output format, and the specific `OCREngine` adapter to handle the input type it receives (or throw/convert if it only supports one).

## Consequences

- **Flexibility**: The pipeline can switch between file-based and memory-based processing without changing the core interface.
- **Platform independence**: The domain layer does not depend on `dart:io` or platform specific image types (like `ui.Image` or `cgImage`).
- **Complexity**: Adapters must potentially handle multiple input types or explicitly check/cast and convert if they have strict requirements (e.g. a Windows adapter might need to write bytes to a temp file if the API demands a file, or vice versa).
- **Testability**: Tests can easily construct `MemoryOcrInput` or `FileOcrInput` to mock the engine.
