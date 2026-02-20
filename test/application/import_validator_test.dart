import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:personal_archive/src/application/application.dart';
import 'package:personal_archive/src/domain/domain.dart';

class FakePdfMetadataReader implements PdfMetadataReader {
  FakePdfMetadataReader({
    this.metadataToReturn,
    this.errorToThrow,
  });

  final PdfMetadata? metadataToReturn;
  final Object? errorToThrow;

  @override
  Future<PdfMetadata> read(String path) async {
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
    return metadataToReturn ?? const PdfMetadata(pageCount: 1);
  }
}

void main() {
  group('ImportValidator', () {
    late Directory tempDir;
    late ImportValidator validator;
    late FakePdfMetadataReader fakeReader;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('import_validator_test');
      fakeReader = FakePdfMetadataReader();
      validator = ImportValidator(
        pdfMetadataReader: fakeReader,
        config: const ImportConfiguration(
          maxFileSizeBytes: 1024, // 1 KB for testing
          maxPageCount: 10, // 10 pages for testing
        ),
      );
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('throws FileDoesNotExistError when file does not exist', () async {
      final file = File('${tempDir.path}/missing.pdf');

      expect(
        () => validator.validateFile(file.path),
        throwsA(isA<FileDoesNotExistError>()),
      );
    });

    test('throws InvalidPdfFormatError when file extension is not .pdf',
        () async {
      final file = File('${tempDir.path}/test.txt')..createSync();

      expect(
        () => validator.validateFile(file.path),
        throwsA(isA<InvalidPdfFormatError>()),
      );
    });

    test('throws FileTooLargeError when file exceeds max size', () async {
      final file = File('${tempDir.path}/large.pdf')..createSync();
      // Write 2 KB of data
      file.writeAsBytesSync(List.filled(2048, 0));

      expect(
        () => validator.validateFile(file.path),
        throwsA(isA<FileTooLargeError>()),
      );
    });

    test(
        'throws InvalidPdfFormatError when PdfMetadataReader throws PdfReadError',
        () async {
      final file = File('${tempDir.path}/invalid.pdf')..createSync();
      fakeReader = FakePdfMetadataReader(
        errorToThrow: const PdfReadError('Invalid PDF'),
      );
      validator = ImportValidator(
        pdfMetadataReader: fakeReader,
        config: const ImportConfiguration(),
      );

      expect(
        () => validator.validateFile(file.path),
        throwsA(isA<InvalidPdfFormatError>()),
      );
    });

    test('throws TooManyPagesError when PDF has too many pages', () async {
      final file = File('${tempDir.path}/long.pdf')..createSync();
      fakeReader = FakePdfMetadataReader(
        metadataToReturn: const PdfMetadata(pageCount: 20),
      );
      validator = ImportValidator(
        pdfMetadataReader: fakeReader,
        config: const ImportConfiguration(maxPageCount: 10),
      );

      expect(
        () => validator.validateFile(file.path),
        throwsA(isA<TooManyPagesError>()),
      );
    });

    test('returns PdfMetadata when validation succeeds', () async {
      final file = File('${tempDir.path}/valid.pdf')..createSync();
      final expectedMetadata = const PdfMetadata(pageCount: 5);
      fakeReader = FakePdfMetadataReader(
        metadataToReturn: expectedMetadata,
      );
      validator = ImportValidator(
        pdfMetadataReader: fakeReader,
        config: const ImportConfiguration(maxPageCount: 10),
      );

      final metadata = await validator.validateFile(file.path);

      expect(metadata, equals(expectedMetadata));
    });
  });
}
