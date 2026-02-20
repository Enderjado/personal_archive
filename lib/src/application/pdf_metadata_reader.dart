import '../domain/pdf_metadata.dart';

/// Typed error thrown when a PDF file cannot be read or parsed.
class PdfReadError implements Exception {
  const PdfReadError(this.message, [this.cause]);

  /// A descriptive message explaining the failure.
  final String message;

  /// The underlying exception or error that caused the failure, if any.
  final Object? cause;

  @override
  String toString() {
    if (cause != null) {
      return 'PdfReadError: $message (Cause: $cause)';
    }
    return 'PdfReadError: $message';
  }
}

/// Abstraction for reading metadata from PDF files.
abstract class PdfMetadataReader {
  /// Reads metadata (such as page count) from the PDF at the given [path].
  ///
  /// Throws a [PdfReadError] if the file does not exist, is not a valid PDF,
  /// or cannot be read.
  Future<PdfMetadata> read(String path);
}
