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
import 'package:personal_archive/src/application/ocr_pipeline_errors.dart';
import 'package:personal_archive/src/application/ocr_result.dart';
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

    // -------------------------------------------------------------------------
    // Guard: document not found
    // -------------------------------------------------------------------------

    test('throws DocumentNotFoundError when document does not exist', () async {
      when(() => mockDocumentRepository.findById(any()))
          .thenAnswer((_) async => null);

      await expectLater(
        () => pipeline.runOcrForDocument('missing-id'),
        throwsA(isA<DocumentNotFoundError>()),
      );

      verify(() => mockDocumentRepository.findById('missing-id')).called(1);
      verifyNever(() => mockRenderer.renderPage(any(), any()));
      verifyNever(() => mockOcrEngine.extractText(any()));
      verifyNever(() => mockDocumentRepository.update(any()));
    });

    // -------------------------------------------------------------------------
    // Guard: invalid document state
    // -------------------------------------------------------------------------

    for (final status in [
      DocumentStatus.processing,
      DocumentStatus.completed,
      DocumentStatus.failed,
    ]) {
      test('throws InvalidDocumentStateError when document is $status', () async {
        when(() => mockDocumentRepository.findById(any()))
            .thenAnswer((_) async => makeDocument(status: status));

        await expectLater(
          () => pipeline.runOcrForDocument('doc-1'),
          throwsA(
            isA<InvalidDocumentStateError>().having(
              (e) => e.currentStatus,
              'currentStatus',
              status,
            ),
          ),
        );

        verify(() => mockDocumentRepository.findById('doc-1')).called(1);
        verifyNever(() => mockRenderer.renderPage(any(), any()));
        verifyNever(() => mockOcrEngine.extractText(any()));
        verifyNever(() => mockDocumentRepository.update(any()));
      });
    }

    // -------------------------------------------------------------------------
    // Success path
    // -------------------------------------------------------------------------

    test('updates status to completed and each page with OCR results', () async {
      const docId = 'doc-1';
      final doc = makeDocument(id: docId);
      final pages = makePages(3, documentId: docId);
      final ocrInput = MemoryOcrInput(Uint8List(4));
      const ocrPageResult = OcrPageResult(rawText: 'hello', confidence: 0.8);

      when(() => mockDocumentRepository.findById(docId))
          .thenAnswer((_) async => doc);
      when(() => mockDocumentRepository.update(any()))
          .thenAnswer((inv) async => inv.positionalArguments.first as Document);
      when(() => mockPageRepository.findByDocumentId(docId))
          .thenAnswer((_) async => pages);
      when(() => mockRenderer.renderPage(any(), any()))
          .thenAnswer((_) async => ocrInput);
      when(() => mockOcrEngine.extractText(any()))
          .thenAnswer((_) async => ocrPageResult);
      when(() => mockPageRepository.update(any())).thenAnswer((_) async {});

      final result = await pipeline.runOcrForDocument(docId);

      // Returned OcrResult is correct.
      expect(result.documentId, docId);
      expect(result.pageCount, 3);
      expect(result.aggregateConfidence, closeTo(0.8, 1e-9));

      // Status transitions: processing → completed.
      final capturedDocs = verify(
        () => mockDocumentRepository.update(captureAny()),
      ).captured.cast<Document>();
      expect(capturedDocs.length, 2);
      expect(capturedDocs[0].status, DocumentStatus.processing);
      expect(capturedDocs[1].status, DocumentStatus.completed);

      // Every page was updated with rawText and ocrConfidence.
      final capturedPages = verify(
        () => mockPageRepository.update(captureAny()),
      ).captured.cast<Page>();
      expect(capturedPages.length, 3);
      for (final p in capturedPages) {
        expect(p.rawText, 'hello');
        expect(p.ocrConfidence, 0.8);
      }
    });

    // -------------------------------------------------------------------------
    // FTS sync
    // -------------------------------------------------------------------------

    test('calls FTS sync exactly once with the document ID after all pages processed', () async {
      const docId = 'doc-1';
      final doc = makeDocument(id: docId);
      final pages = makePages(3, documentId: docId);
      final ocrInput = MemoryOcrInput(Uint8List(4));
      const ocrPageResult = OcrPageResult(rawText: 'world', confidence: 0.9);

      when(() => mockDocumentRepository.findById(docId))
          .thenAnswer((_) async => doc);
      when(() => mockDocumentRepository.update(any()))
          .thenAnswer((inv) async => inv.positionalArguments.first as Document);
      when(() => mockPageRepository.findByDocumentId(docId))
          .thenAnswer((_) async => pages);
      when(() => mockRenderer.renderPage(any(), any()))
          .thenAnswer((_) async => ocrInput);
      when(() => mockOcrEngine.extractText(any()))
          .thenAnswer((_) async => ocrPageResult);
      when(() => mockPageRepository.update(any())).thenAnswer((_) async {});

      await pipeline.runOcrForDocument(docId);

      // FTS sync must be called exactly once, after all pages are processed.
      verify(() => mockSearchIndexSync.syncDocument(docId)).called(1);
      // All 3 pages must have been updated before sync fires.
      verify(() => mockPageRepository.update(any())).called(3);
    });
  });
}
