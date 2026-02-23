/// Configuration for OCR processing and PDF page rendering.
///
/// Controls resolution, language hints, timeouts, and temporary storage
/// when rendering PDF pages and extracting text.
/// Follows the externalized-configuration pattern (ADR 0008).
class OcrConfig {
  const OcrConfig({
    this.dpi = 300,
    this.languageHints = const [],
    this.timeoutPerPage,
    this.tempDir,
  });

  /// The rendering resolution in dots per inch.
  ///
  /// Higher values produce more detailed images (better OCR accuracy)
  /// at the cost of memory and processing time. Defaults to 300 DPI,
  /// which is the industry standard for OCR.
  final int dpi;

  /// Optional BCP-47 language hints for the OCR engine.
  ///
  /// Used to improve recognition accuracy if the engine supports it.
  /// Defaults to an empty list (engine decides or uses its default).
  final List<String> languageHints;

  /// Optional timeout per page for OCR processing.
  ///
  /// If null, no timeout is enforced by the configuration (though the
  /// underlying engine may have its own limits).
  final Duration? timeoutPerPage;

  /// Optional override directory for rendered page images.
  ///
  /// If null, the system temporary directory is used. Useful for testing
  /// or when a specific storage location is required.
  final String? tempDir;
}
