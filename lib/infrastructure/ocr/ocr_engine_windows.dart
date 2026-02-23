import 'package:flutter/services.dart';
import 'package:personal_archive/src/domain/ocr_engine.dart';
import 'package:personal_archive/src/domain/ocr_types.dart';

/// Windows implementation of [OCREngine] backed by the WinRT
/// `Windows.Media.Ocr` API.
///
/// Communicates with the native `WindowsOcrPlugin` over a
/// [MethodChannel] named `personal_archive/ocr`.
///
/// Supports both [FileOcrInput] (preferred — avoids copying bytes across the
/// channel) and [MemoryOcrInput].
class WindowsOcrEngine implements OCREngine {
  /// Creates a [WindowsOcrEngine].
  ///
  /// An optional [channel] can be injected for testing; otherwise the default
  /// production channel is used.
  WindowsOcrEngine({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('personal_archive/ocr');

  // ignore: unused_field
  final MethodChannel _channel;

  @override
  Future<OcrPageResult> extractText(OcrInput input) async {
    // TODO: implement once native plugin is ready
    throw UnimplementedError('WindowsOcrEngine is not yet implemented');
  }
}

/// Factory function matching the signature expected by the conditional-import
/// wiring in `ocr_engine_factory.dart`.
OCREngine createOcrEngine() => WindowsOcrEngine();
