/// Configuration for PDF page rendering.
///
/// Controls resolution and image format when rendering PDF pages for OCR.
/// Follows the externalized-configuration pattern (ADR 0008).
class RenderConfiguration {
  const RenderConfiguration({
    this.dpi = 300,
  });

  /// The rendering resolution in dots per inch.
  ///
  /// Higher values produce more detailed images (better OCR accuracy)
  /// at the cost of memory and processing time. Defaults to 300 DPI,
  /// which is the industry standard for OCR.
  final int dpi;
}
