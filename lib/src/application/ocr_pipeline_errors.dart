import '../domain/document.dart';

/// Base class for errors occurring during the OCR pipeline stage.
///
/// All typed OCR pipeline errors extend this class, allowing callers to
/// catch any pipeline-specific failure and distinguish it from unrelated
/// exceptions. Each subtype carries a human-readable [message] and an
/// optional [cause] for wrapping lower-level errors.
abstract class OcrPipelineError implements Exception {
  const OcrPipelineError();

  /// A human-readable description of the failure.
  String get message;

  /// The underlying error that caused this failure, if any.
  Object? get cause => null;

  @override
  String toString() {
    final buffer = StringBuffer('$runtimeType: $message');
    if (cause != null) {
      buffer.write(' (Cause: $cause)');
    }
    return buffer.toString();
  }
}

/// The requested document does not exist in storage.
class DocumentNotFoundError extends OcrPipelineError {
  const DocumentNotFoundError(this.documentId);

  /// The ID that was looked up but not found.
  final String documentId;

  @override
  String get message => 'Document not found: $documentId';
}

/// The document is not in the expected [DocumentStatus.imported] state.
///
/// OCR processing requires the document to be in [DocumentStatus.imported].
/// This error is thrown when the document has already moved to another status
/// (e.g. [DocumentStatus.processing] or [DocumentStatus.completed]).
class InvalidDocumentStateError extends OcrPipelineError {
  const InvalidDocumentStateError({
    required this.documentId,
    required this.currentStatus,
  });

  /// The ID of the document with the unexpected status.
  final String documentId;

  /// The actual status of the document at the time of the check.
  final DocumentStatus currentStatus;

  @override
  String get message =>
      'Document $documentId is in status $currentStatus, expected imported';
}

/// The PDF file could not be read (missing, corrupt, or not a valid PDF).
class PdfUnreadableError extends OcrPipelineError {
  const PdfUnreadableError({
    required this.documentId,
    required this.filePath,
    this.reason,
    this.cause,
  });

  /// The ID of the document whose PDF could not be read.
  final String documentId;

  /// The path to the PDF file that was unreadable.
  final String filePath;

  /// An optional description of why the file is unreadable.
  final String? reason;

  @override
  final Object? cause;

  @override
  String get message =>
      'PDF unreadable for document $documentId ($filePath)'
      '${reason != null ? ': $reason' : ''}';
}

/// Rendering a PDF page to an image for OCR input failed.
///
/// Wraps the underlying [PdfRenderError] or other rendering exception so
/// callers can identify which page caused the failure.
class OcrRenderError extends OcrPipelineError {
  const OcrRenderError({
    required this.documentId,
    required this.pageNumber,
    this.cause,
  });

  /// The ID of the document being processed.
  final String documentId;

  /// The 1-based page number that failed to render.
  final int pageNumber;

  @override
  final Object? cause;

  @override
  String get message =>
      'Failed to render page $pageNumber of document $documentId';
}
