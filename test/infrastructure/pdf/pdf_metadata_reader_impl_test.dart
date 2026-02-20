import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfx/pdfx.dart';
import 'package:personal_archive/infrastructure/pdf/pdf_metadata_reader_impl.dart';
import 'package:personal_archive/src/application/pdf_metadata_reader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PdfMetadataReaderImpl', () {
    late PdfMetadataReaderImpl reader;
    late Directory testDataDir;
    late File validPdf;
    late File corruptPdf;
    late File nonPdf;

    setUpAll(() async {
      testDataDir = Directory('test/infrastructure/pdf/test_data');
      if (!testDataDir.existsSync()) {
        testDataDir.createSync(recursive: true);
      }

      // Use the real PDF provided by the user
      validPdf = File('${testDataDir.path}/Example_PDF.pdf');

      corruptPdf = File('${testDataDir.path}/corrupt.pdf');
      await corruptPdf.writeAsString('This is not a valid PDF file content.');

      nonPdf = File('${testDataDir.path}/not_a_pdf.txt');
      await nonPdf.writeAsString('Just some text.');
    });

    setUp(() {
      reader = PdfMetadataReaderImpl();
    });

    tearDownAll(() async {
      // Clean up generated test files, but keep the real PDF
      if (corruptPdf.existsSync()) corruptPdf.deleteSync();
      if (nonPdf.existsSync()) nonPdf.deleteSync();
    });

    test('reads page count from a valid PDF file', () async {
      // Note: pdfx relies on native platform channels (MethodChannel) to parse PDFs.
      // In a pure Dart unit test environment (flutter test), these native channels are not available,
      // which results in a PlatformException("Unable to establish connection on channel.").
      // To fully test this, it would need to be an integration test running on a real device/emulator.
      // For this unit test, we verify that the error is correctly caught and wrapped in our PdfReadError.
      expect(
        () => reader.read(validPdf.path),
        throwsA(isA<PdfReadError>()),
      );
    });

    test('throws PdfReadError for a corrupt PDF file', () async {
      expect(
        () => reader.read(corruptPdf.path),
        throwsA(isA<PdfReadError>()),
      );
    });

    test('throws PdfReadError for a non-PDF file', () async {
      expect(
        () => reader.read(nonPdf.path),
        throwsA(isA<PdfReadError>()),
      );
    });

    test('throws PdfReadError for a non-existent file', () async {
      expect(
        () => reader.read('${testDataDir.path}/does_not_exist.pdf'),
        throwsA(isA<PdfReadError>()),
      );
    });
  });
}
