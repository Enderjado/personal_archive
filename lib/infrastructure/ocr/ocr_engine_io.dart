import 'dart:io' show Platform;

import 'package:personal_archive/infrastructure/ocr/ocr_engine_macos.dart'
    as macos;
import 'package:personal_archive/infrastructure/ocr/ocr_engine_windows.dart'
    as windows;
import 'package:personal_archive/src/domain/ocr_engine.dart';
import 'package:personal_archive/src/domain/ocr_error.dart';

/// Creates the platform-appropriate [OCREngine] on dart:io targets.
///
/// Supported platforms:
/// - macOS → [macos.MacOSOcrEngine] (Apple Vision)
/// - Windows → [windows.WindowsOcrEngine] (WinRT Windows.Media.Ocr)
///
/// Other platforms throw [OcrEngineError].
OCREngine createOcrEngine() {
  if (Platform.isMacOS) {
    return macos.createOcrEngine();
  }
  if (Platform.isWindows) {
    return windows.createOcrEngine();
  }
  throw const OcrEngineError('OCR is not available on this platform');
}
