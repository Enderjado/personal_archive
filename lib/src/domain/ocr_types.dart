/// Represents the input source for an OCR operation.
///
/// This is a sealed class to allow for different types of inputs (e.g., file path,
/// bytes, etc.) in a type-safe way.
sealed class OcrInput {
  const OcrInput();
}

/// An OCR input that points to a file on the local filesystem.
class FileOcrInput extends OcrInput {
  final String filePath;

  const FileOcrInput(this.filePath);

  @override
  String toString() => 'FileOcrInput(filePath: $filePath)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FileOcrInput && other.filePath == filePath;
  }

  @override
  int get hashCode => filePath.hashCode;
}

/// Represents the result of an OCR operation on a single page.
class OcrPageResult {
  /// The raw text extracted from the page.
  ///
  /// This is never null, but may be empty if no text was found.
  final String rawText;

  /// The confidence score of the extraction, from 0.0 to 1.0.
  ///
  /// This may be null if the underlying engine does not support confidence scores.
  final double? confidence;

  const OcrPageResult({
    required this.rawText,
    this.confidence,
  });

  @override
  String toString() =>
      'OcrPageResult(rawText: $rawText, confidence: $confidence)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OcrPageResult &&
        other.rawText == rawText &&
        other.confidence == confidence;
  }

  @override
  int get hashCode => Object.hash(rawText, confidence);
}
