import 'package:flutter/services.dart';
import 'package:personal_archive/src/domain/ocr_engine.dart';
import 'package:personal_archive/src/domain/ocr_error.dart';
import 'package:personal_archive/src/domain/ocr_types.dart';

/// macOS implementation of [OCREngine] backed by Apple Vision.
///
/// Communicates with the native `VisionOcrPlugin` over a
/// [MethodChannel] named `personal_archive/ocr`.
///
/// Supports both [FileOcrInput] (preferred — avoids copying bytes across the
/// channel) and [MemoryOcrInput].
class MacOSOcrEngine implements OCREngine {
  /// Creates a [MacOSOcrEngine].
  ///
  /// An optional [channel] can be injected for testing; otherwise the default
  /// production channel is used.
  MacOSOcrEngine({MethodChannel? channel})
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

    try {
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
    } on PlatformException catch (e) {
      throw OcrEngineError(
        e.message ?? 'Unknown platform error during OCR',
        e,
      );
    }
  }
}

/// Factory function matching the signature expected by the conditional-import
/// wiring in `ocr_engine_factory.dart`.
OCREngine createOcrEngine() => MacOSOcrEngine();
