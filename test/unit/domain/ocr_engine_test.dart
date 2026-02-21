import 'package:flutter_test/flutter_test.dart';
import 'package:personal_archive/src/domain/domain.dart';
import 'package:personal_archive/src/domain/ocr_engine.dart';

// Mock implementation to verify the interface contract
class MockOcrEngine implements OCREngine {
  @override
  Future<OcrPageResult> extractText(OcrInput input) async {
    if (input is FileOcrInput) {
      if (input.filePath.contains('error')) {
        throw const OcrEngineError('Mock failure');
      }
      return const OcrPageResult(rawText: 'Mock Text', confidence: 0.95);
    }
    return const OcrPageResult(rawText: '', confidence: 0.0);
  }
}

void main() {
  group('OCREngine Interface Contract', () {
    test('can be implemented and return result', () async {
      final engine = MockOcrEngine();
      final result =
          await engine.extractText(const FileOcrInput('/path/to/image.png'));

      expect(result, isA<OcrPageResult>());
      expect(result.rawText, 'Mock Text');
      expect(result.confidence, 0.95);
    });

    test('can throw OcrEngineError', () async {
      final engine = MockOcrEngine();
      expect(
        () => engine.extractText(const FileOcrInput('/path/to/error.png')),
        throwsA(isA<OcrEngineError>()),
      );
    });

    test('OcrInput equality', () {
      const input1 = FileOcrInput('/path/a');
      const input2 = FileOcrInput('/path/a');
      const input3 = FileOcrInput('/path/b');

      expect(input1, equals(input2));
      expect(input1, isNot(equals(input3)));
    });

    test('OcrPageResult equality', () {
      const res1 = OcrPageResult(rawText: 'A', confidence: 1.0);
      const res2 = OcrPageResult(rawText: 'A', confidence: 1.0);
      const res3 = OcrPageResult(rawText: 'B', confidence: 0.5);

      expect(res1, equals(res2));
      expect(res1, isNot(equals(res3)));
    });
  });
}
