import 'package:personal_archive/src/domain/ocr_engine.dart';
import 'package:personal_archive/src/domain/ocr_error.dart';
import 'package:personal_archive/src/domain/ocr_types.dart';

/// Fallback OCR engine for platforms without a native OCR implementation.
///
/// This stub is selected via conditional imports on platforms that do not
/// have a native adapter (e.g. web, Linux). Every method throws immediately.
class StubOcrEngine implements OCREngine {
  @override
  Future<OcrPageResult> extractText(OcrInput input) {
    throw const OcrEngineError('OCR is not available on this platform');
  }
}

/// Factory function matching the signature expected by the conditional-import
/// wiring in `ocr_engine_factory.dart`.
OCREngine createOcrEngine() => StubOcrEngine();
