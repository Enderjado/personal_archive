import 'dart:typed_data' show Uint8List;

/// Represents the input source for an OCR operation.
///
/// This allows for different types of inputs (e.g., file path,
/// bytes, etc.) in a type-safe way.
abstract class OcrInput {
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

/// An OCR input backed by in-memory image bytes.
///
/// This avoids disk round-trips when the renderer can produce image data
/// directly and the OCR engine can consume byte buffers.
class MemoryOcrInput extends OcrInput {
  /// The raw image bytes (e.g. PNG or JPEG encoded).
  final Uint8List bytes;

  /// The width of the image in pixels, if known.
  final int? width;

  /// The height of the image in pixels, if known.
  final int? height;

  const MemoryOcrInput(this.bytes, {this.width, this.height});

  @override
  String toString() =>
      'MemoryOcrInput(bytesLength: ${bytes.lengthInBytes}, '
      'width: $width, height: $height)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MemoryOcrInput &&
        other.bytes == bytes &&
        other.width == width &&
        other.height == height;
  }

  @override
  int get hashCode => Object.hash(bytes, width, height);
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
