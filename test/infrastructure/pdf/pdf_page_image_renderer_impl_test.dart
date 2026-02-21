import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:personal_archive/infrastructure/pdf/pdf_page_image_renderer_impl.dart';
import 'package:personal_archive/src/application/pdf_page_image_renderer.dart';

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
}
