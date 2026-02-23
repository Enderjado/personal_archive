import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_archive/infrastructure/ocr/ocr_engine_macos.dart';
import 'package:personal_archive/src/domain/ocr_error.dart';
import 'package:personal_archive/src/domain/ocr_types.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MethodChannel channel;
  late MacOSOcrEngine engine;

  setUp(() {
    channel = const MethodChannel('personal_archive/ocr');
    engine = MacOSOcrEngine(channel: channel);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  /// Installs a mock handler that returns the given [response] map.
  void mockChannelSuccess(Map<String, dynamic> response) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      expect(call.method, equals('recognizeText'));
      return response;
    });
  }

  /// Installs a mock handler that throws a [PlatformException].
  void mockChannelError({
    required String code,
    String? message,
  }) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      throw PlatformException(code: code, message: message);
    });
  }

  group('MacOSOcrEngine', () {
    group('extractText with FileOcrInput', () {
      test('returns text and confidence from channel', () async {
        mockChannelSuccess({
          'text': 'Hello World',
          'confidence': 0.92,
        });

        final result = await engine.extractText(
          const FileOcrInput('/path/to/image.png'),
        );

        expect(result.rawText, equals('Hello World'));
        expect(result.confidence, closeTo(0.92, 0.001));
      });

      test('sends filePath argument to channel', () async {
        String? receivedPath;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall call) async {
          final args = call.arguments as Map;
          receivedPath = args['filePath'] as String?;
          expect(args.containsKey('imageBytes'), isFalse);
          return <String, dynamic>{'text': '', 'confidence': null};
        });

        await engine.extractText(const FileOcrInput('/tmp/test.png'));
        expect(receivedPath, equals('/tmp/test.png'));
      });
    });

    group('extractText with MemoryOcrInput', () {
      test('returns text and confidence from channel', () async {
        mockChannelSuccess({
          'text': 'Memory OCR result',
          'confidence': 0.85,
        });

        final bytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]);
        final result = await engine.extractText(MemoryOcrInput(bytes));

        expect(result.rawText, equals('Memory OCR result'));
        expect(result.confidence, closeTo(0.85, 0.001));
      });

      test('sends imageBytes argument to channel', () async {
        Uint8List? receivedBytes;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall call) async {
          final args = call.arguments as Map;
          receivedBytes = args['imageBytes'] as Uint8List?;
          expect(args.containsKey('filePath'), isFalse);
          return <String, dynamic>{'text': '', 'confidence': null};
        });

        final bytes = Uint8List.fromList([1, 2, 3, 4]);
        await engine.extractText(MemoryOcrInput(bytes));
        expect(receivedBytes, equals(bytes));
      });
    });

    group('confidence handling', () {
      test('maps null confidence from channel', () async {
        mockChannelSuccess({
          'text': 'No confidence',
          'confidence': null,
        });

        final result = await engine.extractText(
          const FileOcrInput('/path/to/image.png'),
        );

        expect(result.rawText, equals('No confidence'));
        expect(result.confidence, isNull);
      });
    });

    group('error handling', () {
      test('wraps PlatformException as OcrEngineError', () async {
        mockChannelError(code: 'OCR_FAILED', message: 'Vision failed');

        expect(
          () => engine.extractText(const FileOcrInput('/bad/image.png')),
          throwsA(
            isA<OcrEngineError>()
                .having((e) => e.message, 'message', contains('Vision failed'))
                .having(
                    (e) => e.originalError, 'originalError',
                    isA<PlatformException>()),
          ),
        );
      });

      test('wraps PlatformException with null message', () async {
        mockChannelError(code: 'IMAGE_LOAD_FAILED');

        expect(
          () => engine.extractText(const FileOcrInput('/bad/image.png')),
          throwsA(
            isA<OcrEngineError>().having(
              (e) => e.message,
              'message',
              contains('Unknown platform error'),
            ),
          ),
        );
      });

      test('throws OcrEngineError for unsupported OcrInput subtype', () {
        final unsupported = _UnknownOcrInput();

        expect(
          () => engine.extractText(unsupported),
          throwsA(
            isA<OcrEngineError>().having(
              (e) => e.message,
              'message',
              contains('Unsupported OcrInput type'),
            ),
          ),
        );
      });
    });
  });
}

/// A custom [OcrInput] subclass that is intentionally not handled
/// by [MacOSOcrEngine] to test the unsupported-type error path.
class _UnknownOcrInput extends OcrInput {
  const _UnknownOcrInput();
}
