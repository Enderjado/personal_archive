import 'package:flutter_test/flutter_test.dart';
import 'package:personal_archive/infrastructure/ocr/mock_ocr_engine.dart';
import 'package:personal_archive/src/domain/ocr_types.dart';

void main() {
  group('MockOcrEngine', () {
    late MockOcrEngine mockEngine;

    setUp(() {
      mockEngine = MockOcrEngine();
    });

    test('throws UnimplementedError when not configured', () {
      expect(
        () => mockEngine.extractText(const FileOcrInput('test.png')),
        throwsUnimplementedError,
      );
    });

    test('returns fixed success response', () async {
      const result = OcrPageResult(rawText: 'Test text', confidence: 0.9);
      mockEngine.setFixedResponse(result);

      final output1 = await mockEngine.extractText(const FileOcrInput('test.png'));
      final output2 = await mockEngine.extractText(const FileOcrInput('test.png'));

      expect(output1.rawText, equals('Test text'));
      expect(output1.confidence, equals(0.9));
      expect(output2.rawText, equals('Test text'));
    });

    test('throws fixed error response', () {
      final error = Exception('OCR failed');
      mockEngine.setFixedResponse(error);

      expect(
        () => mockEngine.extractText(const FileOcrInput('test.png')),
        throwsA(error),
      );
    });

    test('processes queued responses sequentially', () async {
      const result1 = OcrPageResult(rawText: 'First', confidence: 1.0);
      const result2 = OcrPageResult(rawText: 'Second', confidence: 0.8);
      final error = Exception('Scheduled failure');

      mockEngine.queueResponse(result1);
      mockEngine.queueResponse(error);
      mockEngine.queueResponse(result2);

      expect(
        await mockEngine.extractText(const FileOcrInput('test.png')),
        equals(result1),
      );

      expect(
        () => mockEngine.extractText(const FileOcrInput('test.png')),
        throwsA(error),
      );

      expect(
        await mockEngine.extractText(const FileOcrInput('test.png')),
        equals(result2),
      );
    });

    test('falls back to fixed response after queue is exhausted', () async {
      const fixed = OcrPageResult(rawText: 'Fixed', confidence: 0.5);
      const queued = OcrPageResult(rawText: 'Queued', confidence: 1.0);

      mockEngine.setFixedResponse(fixed);
      mockEngine.queueResponse(queued);

      expect(
        await mockEngine.extractText(const FileOcrInput('test.png')),
        equals(queued),
      );

      expect(
        await mockEngine.extractText(const FileOcrInput('test.png')),
        equals(fixed),
      );
    });
  });
}
