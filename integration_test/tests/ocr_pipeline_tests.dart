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

    // TODO(commit-5): assert every page carries rawText and ocrConfidence from mock
    // TODO(commit-6): assert FTS query surfaces document after OCR writes text

    // ── Failure-path tests (commit 7) ────────────────────────────────────

    // TODO(commit-7): assert document transitions to `failed` when OCR throws mid-run
  });
}
