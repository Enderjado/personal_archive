import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'package:personal_archive/infrastructure/file_storage/local_document_file_storage.dart';
import 'package:personal_archive/infrastructure/ocr/ocr_engine_macos.dart';
import 'package:personal_archive/infrastructure/pdf/pdf_metadata_reader_impl.dart';
import 'package:personal_archive/infrastructure/pdf/pdf_page_image_renderer_impl.dart';
import 'package:personal_archive/infrastructure/sqlite/migrations/migration_runner.dart';
import 'package:personal_archive/infrastructure/sqlite/sqlite_document_repository.dart';
import 'package:personal_archive/infrastructure/sqlite/sqlite_fts_sync_service.dart';
import 'package:personal_archive/infrastructure/sqlite/sqlite_page_repository.dart';
import 'package:personal_archive/src/application/document_pipeline_impl.dart';
import 'package:personal_archive/src/application/import_validator.dart';
import 'package:personal_archive/src/domain/document.dart';

import '../helpers/mock_ocr_engine.dart';
import '../helpers/mock_pdf_page_image_renderer.dart';
import '../helpers/platform_guard.dart';
import '../helpers/test_database.dart';
import '../helpers/test_storage.dart';

void main() {
  late Directory storageDir;
  late sqlite.Database db;
  late MigrationDb migrationDb;

  late SqliteDocumentRepository documentRepo;
  late SqlitePageRepository pageRepo;
  late SqliteFtsSyncService ftsSync;
  late LocalDocumentFileStorage fileStorage;
  late PdfMetadataReaderImpl metadataReader;

  late String importedDocumentId;

  group(
    'Real macOS OCR – platform integration',
    skip: platformSkip(Platform.isMacOS, 'requires macOS'),
    () {
      setUp(() async {
        storageDir = await setupTestStorage();
        final result = await setupTestDatabase();
        db = result.db;
        migrationDb = result.migrationDb;

        documentRepo = SqliteDocumentRepository(migrationDb);
        pageRepo = SqlitePageRepository(migrationDb);
        ftsSync = SqliteFtsSyncService(migrationDb);
        fileStorage = LocalDocumentFileStorage(storageDir.path);
        metadataReader = PdfMetadataReaderImpl();

        // Import the shared test PDF using stub OCR so the document reaches
        // the `imported` state ready for the real OCR step.
        final importPipeline = DocumentPipelineImpl(
          validator: ImportValidator(pdfMetadataReader: metadataReader),
          fileStorage: fileStorage,
          metadataReader: metadataReader,
          documentRepository: documentRepo,
          pageRepository: pageRepo,
          searchIndexSync: ftsSync,
          renderer: MockPdfPageImageRenderer(),
          ocrEngine: MockOcrEngine(pages: const []),
        );

        final assetData =
            await rootBundle.load('integration_test/assets/Example_PDF.pdf');
        final inputFile =
            File(p.join(storageDir.path, 'real_macos_ocr_input.pdf'));
        await inputFile.writeAsBytes(assetData.buffer.asUint8List());

        final importResult =
            await importPipeline.importFromPath(inputFile.path);
        importedDocumentId = importResult.document.id;
      });

      tearDown(() async {
        await cleanupTestStorage(storageDir);
        db.dispose();
      });

      testWidgets(
        'runOcrForDocument with real MacOSOcrEngine: document reaches completed',
        (WidgetTester tester) async {
          // Arrange: wire the pipeline with real macOS OCR and real renderer.
          final ocrPipeline = DocumentPipelineImpl(
            validator: ImportValidator(pdfMetadataReader: metadataReader),
            fileStorage: fileStorage,
            metadataReader: metadataReader,
            documentRepository: documentRepo,
            pageRepository: pageRepo,
            searchIndexSync: ftsSync,
            renderer: PdfPageImageRendererImpl(),
            ocrEngine: MacOSOcrEngine(),
          );

          // Act.
          final result =
              await ocrPipeline.runOcrForDocument(importedDocumentId);

          // Assert: pipeline returned a coherent OcrResult.
          expect(result.documentId, importedDocumentId);
          expect(result.pageCount, greaterThan(0));

          // Assert: document status updated to completed.
          final savedDoc = await documentRepo.findById(importedDocumentId);
          expect(savedDoc, isNotNull);
          expect(savedDoc!.status, DocumentStatus.completed);

          // Assert: at least one page has non-empty rawText.
          final pages = await pageRepo.findByDocumentId(importedDocumentId);
          final pagesWithText =
              pages.where((pg) => pg.rawText != null && pg.rawText!.isNotEmpty);
          expect(
            pagesWithText,
            isNotEmpty,
            reason: 'real OCR should extract text from at least one page',
          );

          // Assert: ocrConfidence is present on pages that have text
          // (Apple Vision always provides a confidence score).
          final pagesWithConfidence = pagesWithText
              .where((pg) => pg.ocrConfidence != null);
          expect(
            pagesWithConfidence,
            isNotEmpty,
            reason: 'Apple Vision should provide ocrConfidence for OCR pages',
          );
        },
      );
    },
  );
}
