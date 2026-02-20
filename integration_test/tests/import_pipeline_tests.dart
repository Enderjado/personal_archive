import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:path/path.dart' as p;

import 'package:personal_archive/infrastructure/sqlite/migrations/migration_runner.dart';
import 'package:personal_archive/infrastructure/sqlite/sqlite_document_repository.dart';
import 'package:personal_archive/infrastructure/sqlite/sqlite_page_repository.dart';
import 'package:personal_archive/infrastructure/sqlite/sqlite_fts_sync_service.dart';
import 'package:personal_archive/infrastructure/file_storage/local_document_file_storage.dart';
import 'package:personal_archive/infrastructure/pdf/pdf_metadata_reader_impl.dart';
import 'package:personal_archive/src/application/document_pipeline_impl.dart';
import 'package:personal_archive/src/application/import_validator.dart';
import 'package:personal_archive/src/domain/domain.dart';

import '../helpers/test_database.dart';
import '../helpers/test_storage.dart';

void main() {
  late Directory storageDir;
  late sqlite.Database db;
  late MigrationDb migrationDb;

  group('Import Pipeline Integration Tests', () {
    setUp(() async {
      storageDir = await setupTestStorage();
      final result = await setupTestDatabase();
      db = result.db;
      migrationDb = result.migrationDb;
    });

    tearDown(() async {
      await cleanupTestStorage(storageDir);
      db.dispose();
    });

    testWidgets('Verify Test Environment Setup', (WidgetTester tester) async {
      // Verify storage exists
      expect(storageDir.existsSync(), isTrue);
      
      // Verify DB has migrations applied
      final result = db.select('SELECT count(*) as count FROM schema_migrations');
      expect(result.first['count'], greaterThan(0)); 
    });

    testWidgets('Full Document Import Pipeline Success', (WidgetTester tester) async {
      // 1. Arrange: Setup dependencies
      final documentRepo = SqliteDocumentRepository(migrationDb);
      final pageRepo = SqlitePageRepository(migrationDb);
      final ftsSync = SqliteFtsSyncService(migrationDb);
      final fileStorage = LocalDocumentFileStorage(storageDir.path);
      final metadataReader = PdfMetadataReaderImpl();
      final validator = ImportValidator(
        pdfMetadataReader: metadataReader,
      );

      final pipeline = DocumentPipelineImpl(
        validator: validator,
        fileStorage: fileStorage,
        metadataReader: metadataReader,
        documentRepository: documentRepo,
        pageRepository: pageRepo,
        searchIndexSync: ftsSync,
      );

      // Create a temporary input file from assets
      final assetData = await rootBundle.load('integration_test/assets/Example_PDF.pdf');
      final inputFile = File(p.join(storageDir.path, 'input_test.pdf'));
      await inputFile.writeAsBytes(assetData.buffer.asUint8List());

      // 2. Act: Run the pipeline
      final result = await pipeline.importFromPath(inputFile.path);

      // 3. Assert: Verify the result object
      expect(result.document, isNotNull);
      expect(result.pageCount, 13);
      final docId = result.document.id;

      // 4. Assert: Database state (Documents)
      final savedDoc = await documentRepo.findById(docId);
      expect(savedDoc, isNotNull);
      expect(savedDoc!.id, docId);
      expect(savedDoc.status, DocumentStatus.imported);
      expect(savedDoc.title, 'input_test'); // Derived from filename

      // 5. Assert: Database state (Pages)
      final savedPages = await pageRepo.findByDocumentId(docId);
      expect(savedPages.length, 13);
      expect(savedPages.first.pageNumber, 1);
      expect(savedPages.first.documentId, docId);

      // 6. Assert: File Storage
      final storedPath = fileStorage.pathForDocument(docId);
      expect(File(storedPath).existsSync(), isTrue);
      // The stored file should be different path than input file
      expect(storedPath, isNot(inputFile.path));

      // 7. Assert: FTS Index (if applicable at this stage)
      // Assuming import adds to FTS or at least makes it available for search
      // Depending on implementation, import might trigger FTS sync or not.
      // Based on pipeline description, indexing happens later or via sync.
      // We can check if `searchIndexSync` was called or if data is in FTS table.
      // Since this is an integration test with real FTS service, we can query it.
      // Note: Documents might not be in FTS immediately after import if FTS sync is async or part of a later stage.
      // But `DocumentPipelineImpl` calls `searchIndexSync`.
      
      // FTS verification: query by title content to confirm indexing
      final ftsResult = db.select(
        "SELECT * FROM documents_fts WHERE documents_fts MATCH ?",
        ['input_test'],
      );
      expect(ftsResult, isNotEmpty);
    });

    testWidgets('Import Pipeline Failure Cleanup', (WidgetTester tester) async {
      // 1. Arrange: Setup dependencies
      final documentRepo = SqliteDocumentRepository(migrationDb);
      final pageRepo = SqlitePageRepository(migrationDb);
      final ftsSync = SqliteFtsSyncService(migrationDb);
      final fileStorage = LocalDocumentFileStorage(storageDir.path);
      final metadataReader = PdfMetadataReaderImpl();
      final validator = ImportValidator(
        pdfMetadataReader: metadataReader,
      );

      final pipeline = DocumentPipelineImpl(
        validator: validator,
        fileStorage: fileStorage,
        metadataReader: metadataReader,
        documentRepository: documentRepo,
        pageRepository: pageRepo,
        searchIndexSync: ftsSync,
      );

      // Create a dummy file that is NOT a PDF to trigger a validation error or processing error
      final invalidFile = File(p.join(storageDir.path, 'invalid_test.txt'));
      await invalidFile.writeAsString('This is not a PDF content');

      // 2. Act & Assert: Expect an error when importing
      try {
        await pipeline.importFromPath(invalidFile.path);
        fail('Pipeline should fail for invalid PDF');
      } catch (e) {
        // We expect it to fail, ideally with a specific error type if we knew it
        // e.g. ImportValidationError or StorageError
        expect(e, isNotNull);
      }

      // 3. Assert: Verify no data was persisted (Cleanup check)
      
      // Database should be empty of documents
      final docs = await documentRepo.list();
      expect(docs, isEmpty);

      // Files should not be stored in the permanent storage location
      // LocalDocumentFileStorage might create directories, but strictly speaking no documents should be there
      // We check if the storage root contains any files other than our input temp file
      final storedFiles = storageDir.listSync(recursive: true).where((entity) {
        return entity is File && entity.path != invalidFile.path;
      });
      
      expect(storedFiles, isEmpty);
    });
  });
}
