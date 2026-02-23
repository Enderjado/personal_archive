import 'package:flutter/services.dart';
import 'package:personal_archive/src/domain/ocr_engine.dart';
import 'package:personal_archive/src/domain/ocr_error.dart';
import 'package:personal_archive/src/domain/ocr_types.dart';

/// Windows implementation of [OCREngine] backed by the WinRT
/// `Windows.Media.Ocr` API.
///
/// Communicates with the native `WindowsOcrPlugin` over a
/// [MethodChannel] named `personal_archive/ocr`.
///
/// Supports both [FileOcrInput] (preferred — avoids copying bytes across the
/// channel) and [MemoryOcrInput]. The native side accepts any image format
/// decodable by WIC (PNG, JPEG, BMP, TIFF, GIF, JPEG-XR).
class WindowsOcrEngine implements OCREngine {
  /// Creates a [WindowsOcrEngine].
  ///
  /// An optional [channel] can be injected for testing; otherwise the default
  /// production channel is used.
  WindowsOcrEngine({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('personal_archive/ocr');

  final MethodChannel _channel;

  @override
  Future<OcrPageResult> extractText(OcrInput input) async {
    final Map<String, dynamic> args;

    if (input is FileOcrInput) {
      args = <String, dynamic>{'filePath': input.filePath};
    } else if (input is MemoryOcrInput) {
      args = <String, dynamic>{'imageBytes': input.bytes};
    } else {
      throw OcrEngineError(
        'Unsupported OcrInput type: ${input.runtimeType}',
      );
    }

    final result = await _channel.invokeMapMethod<String, dynamic>(
      'recognizeText',
      args,
    );

    if (result == null) {
      throw const OcrEngineError(
        'Native OCR returned null — unexpected channel response',
      );
    }

    final text = result['text'] as String? ?? '';
    final confidence = result['confidence'] as double?;

    return OcrPageResult(rawText: text, confidence: confidence);
  }
}

/// Factory function matching the signature expected by the conditional-import
/// wiring in `ocr_engine_factory.dart`.
OCREngine createOcrEngine() => WindowsOcrEngine();
