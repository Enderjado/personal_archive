/// Platform-conditional OCR engine factory.
///
/// On dart:io targets (macOS, Windows, Linux) this resolves to
/// `ocr_engine_io.dart`, which inspects the OS at runtime.
/// On non-IO targets (web) the stub is used instead.
///
/// Usage:
/// ```dart
/// import 'package:personal_archive/infrastructure/ocr/ocr_engine_factory.dart';
///
/// final engine = createOcrEngine();
/// ```
export 'ocr_engine_stub.dart' if (dart.library.io) 'ocr_engine_io.dart';
