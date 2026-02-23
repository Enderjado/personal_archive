import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:personal_archive/infrastructure/ocr/ocr_engine_stub.dart';
import 'package:personal_archive/src/domain/ocr_error.dart';
import 'package:personal_archive/src/domain/ocr_types.dart';

void main() {
  group('StubOcrEngine', () {
    test('extractText throws OcrEngineError', () {
      final engine = StubOcrEngine();

      expect(
        () => engine.extractText(const FileOcrInput('/any/image.png')),
        throwsA(isA<OcrEngineError>().having(
          (e) => e.message,
          'message',
          contains('not available on this platform'),
        )),
      );
    });

    test('extractText throws for MemoryOcrInput as well', () {
      final engine = StubOcrEngine();
      final input = MemoryOcrInput(
        Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]),
      );

      expect(
        () => engine.extractText(input),
        throwsA(isA<OcrEngineError>()),
      );
    });
  });

  group('createOcrEngine', () {
    test('returns a StubOcrEngine', () {
      final engine = createOcrEngine();
      expect(engine, isA<StubOcrEngine>());
    });
  });
}
