# 16. Platform Conditional Compilation for OCR

Date: 2026-02-21

Status: Accepted

## Context

The OCR implementation relies on platform-specific APIs and potentially platform-specific Dart packages (e.g., `google_ml_kit` on mobile, specific Windows/macOS FFI wrappers on desktop).
Directly importing a Windows-specific library in a file compiled for macOS (or vice versa) can lead to compilation errors or runtime crashes, especially if the package uses `dart:ffi` binding to symbols not present on the OS.
We need a strategy to ensure that:
1.  The core domain and application layers remain platform-agnostic.
2.  Platform-specific implementations are only loaded/compiled on the matching platform.
3.  The build system does not fail when building for a specific target.

## Decision

We will use **conditional imports** (also known as "stubbing") to isolate platform-specific OCR implementations.

### Implementation Strategy

1.  **Interface**: The `OCREngine` interface is defined in the domain layer (pure Dart, no platform dependencies).
2.  ** implementations**:
    - `infrastructure/ocr/ocr_engine_windows.dart`: Imports Windows-specific packages.
    - `infrastructure/ocr/ocr_engine_macos.dart`: Imports macOS-specific packages.
    - `infrastructure/ocr/ocr_engine_stub.dart`: Throws `UnsupportedError` or returns a no-op implementation.
3.  **Factory/Provider**:
    - A factory file (e.g., `infrastructure/ocr/ocr_engine_factory.dart`) exposes a function `returnOcrEngine()`.
    - It uses Dart's conditional import feature:
      ```dart
      import 'ocr_engine_stub.dart'
        if (dart.library.io) 'ocr_engine_io.dart'
        if (dart.library.html) 'ocr_engine_web.dart'; // (If web support is needed later)
      ```
      *Note: Since standard `if (dart.library.io)` doesn't distinguish OS, we often use a single entry point that checks `Platform.isWindows` at runtime if the imports are safe. However, if strict compile-time isolation is needed (because `import 'package:win32/...'` fails on macOS), we use separate files and the conditional import syntax if possible, or more commonly for Flutter desktop: rely on the plugin system or strictly separated files that are only instantiated based on runtime checks, provided the *imports* themselves don't crash the compiler.*

    **Selected Approach**:
    Since we are likely not writing a full Flutter plugin but rather consuming packages or writing FFI code directly:
    - We will attempt to wrap platform implementations in separate classes.
    - We will use a DI provider (Riverpod) that checks `Platform.isWindows` / `Platform.isMacOS` at **runtime** to select the implementation.
    - **Crucial**: If a platform-specific package (like a Windows FFI wrapper) causes built-time errors on macOS even if unused, we will wrap it in a local package or use conditional imports to prevent the file from being compiled on the wrong platform.

    *Refinement*: To guarantee safety, we will use the **conditional export/import pattern**:
    `ocr_factory.dart`:
    ```dart
    import 'ocr_server_stub.dart'
      if (dart.library.io) 'ocr_service_io.dart';
    
    OCREngine getOcrEngine() => createOcrEngine();
    ```
    
    `ocr_service_io.dart` will implement `createOcrEngine()` by checking `Platform.operatingSystem` and delegating to purely separated implementations if needed, or simply returning the correct class.

## Consequences

- **Isolation**: Windows-specific code is never executed on macOS.
- **Build Safety**: Prevents "symbol not found" errors during linking/compilation.
- **Maintainability**: Clear separation of platform logic.
- **Testing**: Allows easy injection of a mock engine for unit tests without loading native libraries.

## Addendum — macOS Vision OCR Implementation (2026-02-23)

The first concrete platform adapter has been implemented following the strategy
above. This section records the details for future maintainers.

### Method Channel Contract

| Property | Value |
|---|---|
| Channel name | `personal_archive/ocr` |
| Method | `recognizeText` |

**Arguments** (map — exactly one of the two keys must be present):

| Key | Type | Description |
|---|---|---|
| `filePath` | `String` | Absolute path to an image file on disk. Preferred for large images to avoid copying bytes across the channel boundary. |
| `imageBytes` | `Uint8List` (via `FlutterStandardTypedData`) | Raw image bytes (PNG, JPEG, TIFF, or any format `CGImageSource` can decode). |

**Return value** (map):

| Key | Type | Description |
|---|---|---|
| `text` | `String` | Concatenated recognised text, observations joined by `\n`. Empty string if no text was found. |
| `confidence` | `Double?` | Mean per-observation confidence (0.0–1.0), or `null` when no observations were produced. |

**Error codes** (returned as `FlutterError`):

| Code | Meaning |
|---|---|
| `INVALID_ARGUMENTS` | Neither or both of `filePath`/`imageBytes` supplied, or arguments are not a map. |
| `IMAGE_LOAD_FAILED` | The image could not be decoded to a `CGImage`. |
| `OCR_FAILED` | `VNRecognizeTextRequest` or its handler failed. |

### Native Implementation (`macos/Runner/VisionOcrPlugin.swift`)

- Registers on the channel in `MainFlutterWindow.awakeFromNib()` via
  `VisionOcrPlugin.register(with:)`.
- Uses `VNRecognizeTextRequest` with `recognitionLevel = .accurate` and
  `usesLanguageCorrection = true`.
- Vision work is dispatched to `DispatchQueue.global(qos: .userInitiated)`;
  results are returned on the main thread as required by Flutter.
- Supported image formats: anything `CGImageSourceCreateWithURL` /
  `CGImageSourceCreateWithData` can load — PNG, JPEG, TIFF, BMP, GIF, HEIF.

### Deployment Target

The macOS deployment target is **10.15** (Catalina), which is the minimum
version supporting `VNRecognizeTextRequest`. No additional capability
entitlements are required.

### Dart Adapter (`lib/infrastructure/ocr/ocr_engine_macos.dart`)

- `MacOSOcrEngine` implements `OCREngine`.
- Accepts an optional `MethodChannel` in the constructor for test injection.
- Maps `FileOcrInput` → `filePath` argument, `MemoryOcrInput` → `imageBytes`
  argument.
- Catches `PlatformException` and rethrows as `OcrEngineError` with the
  original exception attached.

### Conditional Import Wiring

```
ocr_engine_factory.dart          ← public entry point
  └─ exports ocr_engine_stub.dart        (fallback — throws OcrEngineError)
     if (dart.library.io) ocr_engine_io.dart
       └─ checks Platform.isMacOS at runtime
          └─ delegates to ocr_engine_macos.dart → MacOSOcrEngine
```

### Recommended OcrInput Strategy

For large images (e.g. rendered PDF pages at 300 DPI), prefer `FileOcrInput`
over `MemoryOcrInput` to avoid copying megabytes of pixel data across the
method-channel boundary. `PdfPageImageRendererImpl` currently produces
`MemoryOcrInput`; a future optimisation could write to a temp file and use
`FileOcrInput` instead.
