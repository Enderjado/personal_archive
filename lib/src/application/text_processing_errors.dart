/// Base class for errors occurring during the text processing stage.
///
/// All typed text processing errors extend this class, allowing callers to
/// catch any text-processing-specific failure and distinguish it from
/// unrelated exceptions. Each subtype carries a human-readable [message] and
/// an optional [cause] for wrapping lower-level errors.
abstract class TextProcessingError implements Exception {
  const TextProcessingError();

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

/// The document has no pages; text processing cannot proceed.
///
/// This error is thrown before any processing begins when
/// [PageRepository.findByDocumentId] returns an empty list, ensuring the
/// caller receives a clear signal rather than a silent no-op.
class DocumentHasNoPagesError extends TextProcessingError {
  const DocumentHasNoPagesError(this.documentId);

  /// The ID of the document that has no associated pages.
  final String documentId;

  @override
  String get message => 'Document has no pages: $documentId';
}

/// A storage operation failed while persisting processed text.
class TextProcessingStorageError extends TextProcessingError {
  const TextProcessingStorageError({
    required this.documentId,
    required Object this.cause,
  });

  /// The ID of the document being processed when the error occurred.
  final String documentId;

  @override
  final Object cause;

  @override
  String get message =>
      'Storage failure while processing document $documentId';
}
