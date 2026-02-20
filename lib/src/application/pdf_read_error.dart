/// Typed error raised when a PDF file cannot be read or parsed.
///
/// Wraps infrastructure-level failures so the pipeline and callers never
/// depend on library-specific exception types.
abstract class PdfReadError implements Exception {
  const PdfReadError();
  String get message;
}

/// The file at the given path does not exist or cannot be opened.
class PdfFileNotFoundError extends PdfReadError {
  const PdfFileNotFoundError(this.path);
  final String path;
  @override
  String get message => 'PDF file not found: $path';
}

/// The file exists but is not a valid or parseable PDF.
class PdfInvalidFormatError extends PdfReadError {
  const PdfInvalidFormatError(this.path, {this.cause});
  final String path;
  final Object? cause;
  @override
  String get message =>
      'Invalid PDF format: $path${cause != null ? ' ($cause)' : ''}';
}

/// An unexpected error occurred while reading the PDF.
class PdfUnknownReadError extends PdfReadError {
  const PdfUnknownReadError(this.cause);
  final Object cause;
  @override
  String get message => 'Failed to read PDF: $cause';
}
