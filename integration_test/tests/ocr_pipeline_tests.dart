import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'package:personal_archive/infrastructure/file_storage/local_document_file_storage.dart';
import 'package:personal_archive/infrastructure/pdf/pdf_metadata_reader_impl.dart';
import 'package:personal_archive/infrastructure/sqlite/migrations/migration_runner.dart';
import 'package:personal_archive/infrastructure/sqlite/sqlite_document_repository.dart';
import 'package:personal_archive/infrastructure/sqlite/sqlite_fts_sync_service.dart';
import 'package:personal_archive/infrastructure/sqlite/sqlite_page_repository.dart';
import 'package:personal_archive/src/application/document_pipeline_impl.dart';
import 'package:personal_archive/src/application/import_validator.dart';
import 'package:personal_archive/src/application/ocr_result.dart';
import 'package:personal_archive/src/domain/document.dart';

import '../helpers/mock_ocr_engine.dart';
import '../helpers/mock_pdf_page_image_renderer.dart';
import '../helpers/test_database.dart';
import '../helpers/test_storage.dart';

void main() {
  late Directory storageDir;
  late sqlite.Database db;
  late MigrationDb migrationDb;

  // Shared repository/service objects — rebuilt fresh for every test.
  late SqliteDocumentRepository documentRepo;
  late SqlitePageRepository pageRepo;
  late SqliteFtsSyncService ftsSync;
  late LocalDocumentFileStorage fileStorage;
  late PdfMetadataReaderImpl metadataReader;

  // The document id produced by the import step; available to every test.
  late String importedDocumentId;

  /// Builds a [DocumentPipelineImpl] wired to the shared repositories but
  /// with per-test [renderer] and [ocrEngine] mocks.
  ///
  /// The import step in [setUp] uses stubs; each OCR test constructs its
  /// own pipeline so the mock engines carry the correct per-test responses.
  DocumentPipelineImpl buildPipeline({
    required MockPdfPageImageRenderer renderer,
    required MockOcrEngine ocrEngine,
  }) {
    return DocumentPipelineImpl(
      validator: ImportValidator(pdfMetadataReader: metadataReader),
      fileStorage: fileStorage,
      metadataReader: metadataReader,
      documentRepository: documentRepo,
      pageRepository: pageRepo,
      searchIndexSync: ftsSync,
      renderer: renderer,
      ocrEngine: ocrEngine,
    );
  }

  group('OCR Pipeline Integration Tests', () {
    setUp(() async {
      // 1. Spin up a fresh in-memory SQLite DB with all migrations applied.
      storageDir = await setupTestStorage();
      final result = await setupTestDatabase();
      db = result.db;
      migrationDb = result.migrationDb;

      // 2. Build repository and service objects backed by that DB.
      documentRepo = SqliteDocumentRepository(migrationDb);
      pageRepo = SqlitePageRepository(migrationDb);
      ftsSync = SqliteFtsSyncService(migrationDb);
      fileStorage = LocalDocumentFileStorage(storageDir.path);
      metadataReader = PdfMetadataReaderImpl();

      // 3. Run the import step with stub OCR dependencies so every test
      //    starts from a document already in the `imported` state with
      //    pages persisted in the DB and the PDF stored on disk.
      final importPipeline = buildPipeline(
        renderer: MockPdfPageImageRenderer(),
        ocrEngine: MockOcrEngine(pages: const []),
      );

      final assetData =
          await rootBundle.load('integration_test/assets/Example_PDF.pdf');
      final inputFile =
          File(p.join(storageDir.path, 'ocr_test_input.pdf'));
      await inputFile.writeAsBytes(assetData.buffer.asUint8List());

      final importResult = await importPipeline.importFromPath(inputFile.path);
      importedDocumentId = importResult.document.id;
    });

    tearDown(() async {
      await cleanupTestStorage(storageDir);
      db.dispose();
    });

    // ── Happy-path tests (commits 4, 5, 6) ───────────────────────────────

    testWidgets(
      'runOcrForDocument returns OcrResult and document reaches completed',
      (WidgetTester tester) async {
        // Arrange: one MockOcrResponse per page (test PDF has 13 pages).
        const pageCount = 13;
        final ocrEngine = MockOcrEngine(
          pages: List.generate(
            pageCount,
            (i) => MockOcrResponse(
              rawText: 'mock text for page ${i + 1}',
              confidence: 0.90 + i * 0.001,
            ),
          ),
        );

        final ocrPipeline = buildPipeline(
          renderer: MockPdfPageImageRenderer(),
          ocrEngine: ocrEngine,
        );

        // Act.
        final result = await ocrPipeline.runOcrForDocument(importedDocumentId);

        // Assert: OcrResult shape.
        expect(result, isA<OcrResult>());
        expect(result.documentId, importedDocumentId);
        expect(result.pageCount, pageCount);
        expect(result.aggregateConfidence, isNotNull);

        // Assert: persisted document status.
        final savedDoc = await documentRepo.findById(importedDocumentId);
        expect(savedDoc, isNotNull);
        expect(savedDoc!.status, DocumentStatus.completed);
      },
    );

    testWidgets(
      'every page has rawText and ocrConfidence matching mock output after OCR',
      (WidgetTester tester) async {
        // Arrange: deterministic per-page responses with distinct text and
        // confidence values so any mix-up in ordering is immediately visible.
        const pageCount = 13;
        final responses = List.generate(
          pageCount,
          (i) => MockOcrResponse(
            rawText: 'deterministic page ${i + 1} content',
            confidence: 0.80 + i * 0.01,
          ),
        );

        final ocrPipeline = buildPipeline(
          renderer: MockPdfPageImageRenderer(),
          ocrEngine: MockOcrEngine(pages: responses),
        );

        // Act.
        await ocrPipeline.runOcrForDocument(importedDocumentId);

        // Assert: fetch pages sorted by pageNumber so index == pageNumber - 1.
        final pages = await pageRepo.findByDocumentId(importedDocumentId);
        pages.sort((a, b) => a.pageNumber.compareTo(b.pageNumber));

        expect(pages.length, pageCount);
        for (var i = 0; i < pageCount; i++) {
          final page = pages[i];
          final expected = responses[i];
          expect(
            page.rawText,
            expected.rawText,
            reason: 'rawText mismatch on page ${i + 1}',
          );
          expect(
            page.ocrConfidence,
            closeTo(expected.confidence!, 1e-9),
            reason: 'ocrConfidence mismatch on page ${i + 1}',
          );
        }
      },
    );

    testWidgets(
      'FTS index contains mock OCR text and returns document after runOcrForDocument',
      (WidgetTester tester) async {
        // Arrange: embed a phrase that is unique to the mock OCR output so the
        // FTS query cannot accidentally match the document title or other content.
        const uniquePhrase = 'fts-unique-ocr-phrase';
        const pageCount = 13;
        final ocrPipeline = buildPipeline(
          renderer: MockPdfPageImageRenderer(),
          ocrEngine: MockOcrEngine(
            pages: List.generate(
              pageCount,
              (i) => MockOcrResponse(
                // Only the first page embeds the unique phrase; the rest are
                // plain filler so the FTS match is unambiguous.
                rawText: i == 0
                    ? 'first page contains $uniquePhrase for search'
                    : 'filler text for page ${i + 1}',
                confidence: 0.95,
              ),
            ),
          ),
        );

        // Act.
        await ocrPipeline.runOcrForDocument(importedDocumentId);

        // Assert: FTS table has a row for the document whose content contains
        // the unique phrase.
        final rows = db.select(
          'SELECT document_id FROM documents_fts WHERE documents_fts MATCH ?',
          [uniquePhrase],
        );

        expect(rows, isNotEmpty, reason: 'FTS index should contain the mock OCR phrase');
        expect(
          rows.map((r) => r['document_id']).toList(),
          contains(importedDocumentId),
        );
      },
    );

    // ── Failure-path tests (commit 7) ────────────────────────────────────

    testWidgets(
      'document transitions to failed when OCR engine throws mid-run',
      (WidgetTester tester) async {
        // Arrange: engine succeeds on page 1 (index 0) but throws on page 2
        // (index 1), simulating a partial OCR failure mid-document.
        const pageCount = 13;
        final ocrEngine = MockOcrEngine(
          pages: List.generate(
            pageCount,
            (i) => MockOcrResponse(
              rawText: 'page ${i + 1} text',
              confidence: 0.90,
            ),
          ),
          throwOnPageIndex: 1, // throw on the second extractText call
        );

        final ocrPipeline = buildPipeline(
          renderer: MockPdfPageImageRenderer(),
          ocrEngine: ocrEngine,
        );

        // Act: the pipeline must not let the OcrPipelineError escape uncaught;
        // it should swallow it internally after marking the document as failed.
        // We catch here in case the implementation re-throws (both are valid per
        // the design — what matters is the persisted document state).
        try {
          await ocrPipeline.runOcrForDocument(importedDocumentId);
        } catch (_) {
          // Expected: OcrEnginePipelineError propagated after status update.
        }

        // Assert: document status is `failed` regardless of whether the error
        // was re-thrown.
        final savedDoc = await documentRepo.findById(importedDocumentId);
        expect(savedDoc, isNotNull);
        expect(
          savedDoc!.status,
          DocumentStatus.failed,
          reason: 'document should be marked failed after OCR engine error',
        );

        // Assert: only page 1 (index 0) could have been processed before the
        // throw; at most one page should have rawText set.
        final pages = await pageRepo.findByDocumentId(importedDocumentId);
        final pagesWithText =
            pages.where((p) => p.rawText != null && p.rawText!.isNotEmpty);
        expect(
          pagesWithText.length,
          lessThanOrEqualTo(1),
          reason: 'at most the first page should have rawText after mid-run failure',
        );
      },
    );
  });
}
