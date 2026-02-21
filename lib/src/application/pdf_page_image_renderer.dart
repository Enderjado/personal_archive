import '../domain/ocr_types.dart';

/// Typed error thrown when a PDF page cannot be rendered to an image.
class PdfRenderError implements Exception {
  const PdfRenderError(this.message, [this.cause]);

  /// A descriptive message explaining the failure.
  final String message;

  /// The underlying exception or error that caused the failure, if any.
  final Object? cause;

  @override
  String toString() {
    if (cause != null) {
      return 'PdfRenderError: $message (Cause: $cause)';
    }
    return 'PdfRenderError: $message';
  }
}

/// Abstraction for rendering a single page of a PDF to an [OcrInput].
///
/// The pipeline uses this to convert each PDF page into a form that the
/// [OCREngine] can consume, without coupling to a specific PDF library
/// or rendering approach.
abstract class PdfPageImageRenderer {
  /// Renders page [pageNumber] (1-based) of the PDF at [pdfPath] and returns
  /// an [OcrInput] suitable for the OCR engine.
  ///
  /// Throws a [PdfRenderError] if the file is not a valid PDF or [pageNumber]
  /// is out of range (less than 1 or greater than the document's page count).
  Future<OcrInput> renderPage(String pdfPath, int pageNumber);
}
