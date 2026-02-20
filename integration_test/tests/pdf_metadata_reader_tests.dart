import 'dart:io';

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
      final testPdfPath = _resolveTestDataPath('Example_PDF.pdf');
      _ensureFileExists(testPdfPath);

      final PdfMetadata metadata = await reader.read(testPdfPath);

      expect(metadata.pageCount, equals(13));
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

/// Resolves the path to a file inside the test_data directory.
///
/// When running integration tests on desktop, the working directory may differ
/// from the project root (e.g. it may be the build output directory). We walk
/// up from the current directory until we find the project marker (pubspec.yaml)
/// and resolve relative to that.
String _resolveTestDataPath(String filename) {
  // Try relative first (works when cwd is project root)
  final relative = 'test/infrastructure/pdf/test_data/$filename';
  if (File(relative).existsSync()) return relative;

  // Walk up from cwd looking for the project root
  var dir = Directory.current;
  for (var i = 0; i < 10; i++) {
    final candidate = '${dir.path}/test/infrastructure/pdf/test_data/$filename';
    if (File(candidate).existsSync()) return candidate;
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }

  // Last resort: absolute path based on known project location
  return '/Users/juliusluckefahr/Projects/personal_archive/test/infrastructure/pdf/test_data/$filename';
}

/// Guards against a missing test fixture so the failure message is clear.
void _ensureFileExists(String path) {
  if (!File(path).existsSync()) {
    fail(
      'Test fixture not found at "$path". '
      'Place a valid PDF named "Example_PDF.pdf" in test/infrastructure/pdf/test_data/.',
    );
  }
}
