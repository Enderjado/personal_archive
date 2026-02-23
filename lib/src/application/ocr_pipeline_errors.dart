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
