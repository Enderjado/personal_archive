import 'ocr_types.dart';

/// Defines the contract for an OCR (Optical Character Recognition) engine.
///
/// Implementations of this interface wrap specific OCR libraries or services
/// (e.g., Apple Vision, Tesseract, Windows OCR) to provide a unified way
/// to extract text from images.
abstract class OCREngine {
  /// Extracts text from the given [input].
  ///
  /// Returns a [Future] that completes with an [OcrPageResult] containing the
  /// extracted text and optional confidence score.
  ///
  /// Throws an [OcrEngineError] if the extraction fails.
  Future<OcrPageResult> extractText(OcrInput input);
}
