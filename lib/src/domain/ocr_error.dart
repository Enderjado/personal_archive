/// Base class for errors occurring within the OCR domain.
///
/// This allows the application to distinguish OCR-specific failures from other system errors.
abstract class OcrError implements Exception {
  const OcrError();
  String get message;
}

/// Represents a failure in the underlying OCR engine.
///
/// This wraps any platform-specific errors or unexpected engine behavior.
class OcrEngineError extends OcrError {
  final String description;
  final Object? originalError;

  const OcrEngineError(this.description, [this.originalError]);

  @override
  String get message => 'OCR Engine failed: $description';

  @override
  String toString() =>
      'OcrEngineError: $message${originalError != null ? ' (Cause: $originalError)' : ''}';
}
