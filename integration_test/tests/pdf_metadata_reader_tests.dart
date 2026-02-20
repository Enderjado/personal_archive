import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_archive/infrastructure/pdf/pdf_metadata_reader_impl.dart';
import 'package:personal_archive/src/application/pdf_metadata_reader.dart';
import 'package:personal_archive/src/domain/pdf_metadata.dart';

/// Integration test for PdfMetadataReaderImpl.
///
/// Unlike the unit tests, this runs on a real platform (macOS / Windows) where
/// pdfx's native renderer is available, so we can actually open and parse PDFs.
///
/// Run with:
///   flutter test integration_test/pdf_metadata_reader_test.dart -d macos
///   flutter test integration_test/pdf_metadata_reader_test.dart -d windows
void main() {
  late PdfMetadataReaderImpl reader;

  setUp(() {
    reader = PdfMetadataReaderImpl();
  });

  group('PdfMetadataReaderImpl (integration)', () {
    testWidgets('reads correct page count from a valid PDF',
        (WidgetTester tester) async {
      // Load the PDF from bundled assets and write to a temp file
      final assetData =
          await rootBundle.load('integration_test/assets/Example_PDF.pdf');
      final tempDir = await Directory.systemTemp.createTemp('pdf_test_');
      final testFile = File('${tempDir.path}/Example_PDF.pdf');
      await testFile.writeAsBytes(assetData.buffer.asUint8List());

      try {
        final PdfMetadata metadata = await reader.read(testFile.path);

        expect(metadata.pageCount, equals(13));
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    testWidgets('throws PdfReadError for a corrupt file',
        (WidgetTester tester) async {
      // Create a temporary corrupt file
      final tempDir = await Directory.systemTemp.createTemp('pdf_test_');
      final corruptFile = File('${tempDir.path}/corrupt.pdf');
      await corruptFile.writeAsString('This is not a valid PDF.');

      try {
        expect(
          () => reader.read(corruptFile.path),
          throwsA(isA<PdfReadError>()),
        );
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    testWidgets('throws PdfReadError for a non-existent file',
        (WidgetTester tester) async {
      expect(
        () => reader.read('/tmp/does_not_exist_at_all.pdf'),
        throwsA(isA<PdfReadError>()),
      );
    });
  });
}
