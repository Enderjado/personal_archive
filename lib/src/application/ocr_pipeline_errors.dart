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
