import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:personal_archive/src/application/document_pipeline_impl.dart';
import 'package:personal_archive/src/application/import_validator.dart';
import 'package:personal_archive/src/application/pdf_metadata_reader.dart';
import 'package:personal_archive/src/application/pdf_page_image_renderer.dart';
import 'package:personal_archive/src/application/search_index_sync.dart';
import 'package:personal_archive/src/domain/document.dart';
import 'package:personal_archive/src/domain/document_file_storage.dart';
import 'package:personal_archive/src/domain/document_repository.dart';
import 'package:personal_archive/src/domain/ocr_engine.dart';
import 'package:personal_archive/src/domain/ocr_types.dart';
import 'package:personal_archive/src/domain/page.dart';
import 'package:personal_archive/src/domain/page_repository.dart';

// ---------------------------------------------------------------------------
// Mocktail mocks
// ---------------------------------------------------------------------------

class MockImportValidator extends Mock implements ImportValidator {}

class MockDocumentFileStorage extends Mock implements DocumentFileStorage {}

class MockPdfMetadataReader extends Mock implements PdfMetadataReader {}

class MockDocumentRepository extends Mock implements DocumentRepository {}

class MockPageRepository extends Mock implements PageRepository {}

class MockSearchIndexSync extends Mock implements SearchIndexSync {}

class MockOCREngine extends Mock implements OCREngine {}

class MockPdfPageImageRenderer extends Mock implements PdfPageImageRenderer {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Document makeDocument({
  String id = 'doc-1',
  DocumentStatus status = DocumentStatus.imported,
}) =>
    Document(
      id: id,
      title: 'Test Document',
      filePath: '/storage/doc-1.pdf',
      status: status,
      createdAt: DateTime.utc(2024),
      updatedAt: DateTime.utc(2024),
    );

List<Page> makePages(int count, {String documentId = 'doc-1'}) =>
    List.generate(
      count,
      (i) => Page(
        id: 'page-${i + 1}',
        documentId: documentId,
        pageNumber: i + 1,
      ),
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('DocumentPipelineImpl.runOcrForDocument', () {
    late DocumentPipelineImpl pipeline;
    late MockImportValidator mockValidator;
    late MockDocumentFileStorage mockFileStorage;
    late MockPdfMetadataReader mockMetadataReader;
    late MockDocumentRepository mockDocumentRepository;
    late MockPageRepository mockPageRepository;
    late MockSearchIndexSync mockSearchIndexSync;
    late MockOCREngine mockOcrEngine;
    late MockPdfPageImageRenderer mockRenderer;

    setUp(() {
      mockValidator = MockImportValidator();
      mockFileStorage = MockDocumentFileStorage();
      mockMetadataReader = MockPdfMetadataReader();
      mockDocumentRepository = MockDocumentRepository();
      mockPageRepository = MockPageRepository();
      mockSearchIndexSync = MockSearchIndexSync();
      mockOcrEngine = MockOCREngine();
      mockRenderer = MockPdfPageImageRenderer();

      // Default best-effort stub so individual tests need not repeat it.
      when(() => mockSearchIndexSync.syncDocument(any()))
          .thenAnswer((_) async {});

      pipeline = DocumentPipelineImpl(
        validator: mockValidator,
        fileStorage: mockFileStorage,
        metadataReader: mockMetadataReader,
        documentRepository: mockDocumentRepository,
        pageRepository: mockPageRepository,
        searchIndexSync: mockSearchIndexSync,
        renderer: mockRenderer,
        ocrEngine: mockOcrEngine,
      );

      // Fallback values required by mocktail for any() / captureAny().
      registerFallbackValue(makeDocument());
      registerFallbackValue(
        Page(id: 'fb', documentId: 'fb', pageNumber: 1),
      );
      registerFallbackValue(
        MemoryOcrInput(Uint8List(0)),
      );
    });
  });
}
