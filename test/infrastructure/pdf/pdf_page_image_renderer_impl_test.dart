import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:personal_archive/infrastructure/pdf/pdf_page_image_renderer_impl.dart';
import 'package:personal_archive/src/application/pdf_page_image_renderer.dart';
import 'package:personal_archive/src/domain/ocr_types.dart';
import 'package:personal_archive/src/domain/render_configuration.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PdfPageImageRendererImpl – invalid inputs', () {
    late PdfPageImageRendererImpl renderer;
    late Directory testDataDir;
    late File corruptPdf;
    late File nonPdf;

    setUpAll(() async {
      testDataDir = Directory('test/infrastructure/pdf/test_data');
      if (!testDataDir.existsSync()) {
        testDataDir.createSync(recursive: true);
      }

      corruptPdf = File('${testDataDir.path}/corrupt.pdf');
      await corruptPdf.writeAsString('This is not a valid PDF file content.');

      nonPdf = File('${testDataDir.path}/not_a_pdf.txt');
      await nonPdf.writeAsString('Just some text.');
    });

    setUp(() {
      renderer = PdfPageImageRendererImpl();
    });

    tearDownAll(() async {
      if (corruptPdf.existsSync()) corruptPdf.deleteSync();
      if (nonPdf.existsSync()) nonPdf.deleteSync();
    });

    test('throws PdfRenderError for page number 0', () async {
      expect(
        () => renderer.renderPage('any_path.pdf', 0),
        throwsA(
          isA<PdfRenderError>().having(
            (e) => e.message,
            'message',
            contains('must be >= 1'),
          ),
        ),
      );
    });

    test('throws PdfRenderError for negative page number', () async {
      expect(
        () => renderer.renderPage('any_path.pdf', -1),
        throwsA(
          isA<PdfRenderError>().having(
            (e) => e.message,
            'message',
            contains('must be >= 1'),
          ),
        ),
      );
    });

    test('throws PdfRenderError for a non-existent file', () async {
      expect(
        () => renderer.renderPage(
          '${testDataDir.path}/does_not_exist.pdf',
          1,
        ),
        throwsA(isA<PdfRenderError>()),
      );
    });

    test('throws PdfRenderError for a corrupt PDF file', () async {
      expect(
        () => renderer.renderPage(corruptPdf.path, 1),
        throwsA(isA<PdfRenderError>()),
      );
    });

    test('throws PdfRenderError for a non-PDF file', () async {
      expect(
        () => renderer.renderPage(nonPdf.path, 1),
        throwsA(isA<PdfRenderError>()),
      );
    });

    test('PdfRenderError.toString includes cause when present', () {
      final error = PdfRenderError('test message', Exception('root cause'));
      expect(error.toString(), contains('test message'));
      expect(error.toString(), contains('Cause:'));
    });

    test('PdfRenderError.toString omits cause when absent', () {
      final error = PdfRenderError('test message');
      expect(error.toString(), equals('PdfRenderError: test message'));
      expect(error.toString(), isNot(contains('Cause:')));
    });
  });

  group('PdfPageImageRendererImpl – valid PDF (platform-dependent)', () {
    late PdfPageImageRendererImpl renderer;
    late File validPdf;

    setUpAll(() {
      validPdf = File('test/infrastructure/pdf/test_data/Example_PDF.pdf');
    });

    setUp(() {
      renderer = PdfPageImageRendererImpl();
    });

    test('renderPage on a valid PDF wraps platform error in PdfRenderError',
        () async {
      // Note: pdfx relies on native platform channels (MethodChannel) to render
      // PDF pages. In a pure Dart unit test environment (flutter test), these
      // native channels are not available. To fully test successful rendering,
      // an integration test running on a real device/emulator is required.
      //
      // This unit test verifies that the platform error is correctly caught and
      // wrapped in our PdfRenderError, proving the error-handling path works.
      expect(
        () => renderer.renderPage(validPdf.path, 1),
        throwsA(isA<PdfRenderError>()),
      );
    });
  });

  group('PdfPageImageRendererImpl – configuration', () {
    test('accepts custom RenderConfiguration', () {
      final config = RenderConfiguration(dpi: 150);
      final renderer = PdfPageImageRendererImpl(config: config);
      // Renderer should be created without errors
      expect(renderer, isNotNull);
    });

    test('uses default RenderConfiguration when none provided', () {
      final renderer = PdfPageImageRendererImpl();
      expect(renderer, isNotNull);
    });
  });

  group('MemoryOcrInput', () {
    test('stores bytes and optional dimensions', () {
      final bytes = Uint8List.fromList([1, 2, 3, 4]);
      final input = MemoryOcrInput(bytes, width: 100, height: 200);

      expect(input.bytes, equals(bytes));
      expect(input.width, 100);
      expect(input.height, 200);
    });

    test('allows null dimensions', () {
      final bytes = Uint8List.fromList([1, 2, 3]);
      final input = MemoryOcrInput(bytes);

      expect(input.width, isNull);
      expect(input.height, isNull);
    });

    test('equality compares bytes and dimensions', () {
      final bytes = Uint8List.fromList([1, 2, 3]);
      final a = MemoryOcrInput(bytes, width: 10, height: 20);
      final b = MemoryOcrInput(bytes, width: 10, height: 20);
      final c = MemoryOcrInput(bytes, width: 99, height: 20);

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('hashCode is consistent with equality', () {
      final bytes = Uint8List.fromList([5, 6, 7]);
      final a = MemoryOcrInput(bytes, width: 10, height: 20);
      final b = MemoryOcrInput(bytes, width: 10, height: 20);

      expect(a.hashCode, equals(b.hashCode));
    });

    test('toString includes byte length and dimensions', () {
      final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      final input = MemoryOcrInput(bytes, width: 640, height: 480);

      expect(input.toString(), contains('bytesLength: 5'));
      expect(input.toString(), contains('width: 640'));
      expect(input.toString(), contains('height: 480'));
    });

    test('is a subtype of OcrInput', () {
      final bytes = Uint8List.fromList([1]);
      final input = MemoryOcrInput(bytes);

      expect(input, isA<OcrInput>());
    });
  });
}
