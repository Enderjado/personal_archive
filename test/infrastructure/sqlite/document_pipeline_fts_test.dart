import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:personal_archive/infrastructure/sqlite/migrations/migration_runner.dart';
import 'package:personal_archive/infrastructure/sqlite/sqlite_document_repository.dart';
import 'package:personal_archive/infrastructure/sqlite/sqlite_fts_sync_service.dart';
import 'package:personal_archive/infrastructure/sqlite/sqlite_page_repository.dart';
import 'package:personal_archive/src/application/document_pipeline_impl.dart';
import 'package:personal_archive/src/application/import_validator.dart';
import 'package:personal_archive/src/application/pdf_metadata_reader.dart';
import 'package:personal_archive/src/domain/document_file_storage.dart';
import 'package:personal_archive/src/domain/pdf_metadata.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'sqlite_test_harness.dart';

class MockImportValidator extends Mock implements ImportValidator {}
class MockDocumentFileStorage extends Mock implements DocumentFileStorage {}
class MockPdfMetadataReader extends Mock implements PdfMetadataReader {}

void main() {
  late sqlite.Database rawDb;
  late Sqlite3MigrationDb db;
  late SqliteDocumentRepository docRepo;
  late SqlitePageRepository pageRepo;
  late SqliteFtsSyncService ftsSync;
  late DocumentPipelineImpl pipeline;
  
  late MockImportValidator mockValidator;
  late MockDocumentFileStorage mockFileStorage;
  late MockPdfMetadataReader mockMetadataReader;

  setUp(() async {
    // Ensure test binding is initialized for asset loading (migrations)
    TestWidgetsFlutterBinding.ensureInitialized();

    rawDb = sqlite.sqlite3.openInMemory();
    db = Sqlite3MigrationDb(rawDb);

    // Apply migrations
    final migrations = await loadTestMigrations();
    await MigrationRunner(
      db: db,
      loadMigrations: () async => migrations,
    ).runAll();

    docRepo = SqliteDocumentRepository(db);
    pageRepo = SqlitePageRepository(db);
    ftsSync = SqliteFtsSyncService(db);
    
    mockValidator = MockImportValidator();
    mockFileStorage = MockDocumentFileStorage();
    mockMetadataReader = MockPdfMetadataReader();

    pipeline = DocumentPipelineImpl(
      validator: mockValidator,
      fileStorage: mockFileStorage,
      metadataReader: mockMetadataReader,
      documentRepository: docRepo,
      pageRepository: pageRepo,
      searchIndexSync: ftsSync,
    );
  });

  tearDown(() {
    rawDb.dispose();
  });

  test('imported document is immediately searchable via FTS', () async {
    // Arrange
    const sourcePath = '/tmp/test_document.pdf';
    const storagePath = '/app/storage/uuid.pdf';
    const pageCount = 1;
    const documentTitle = 'test_document';

    when(() => mockValidator.validateFile(sourcePath))
        .thenAnswer((_) async => const PdfMetadata(pageCount: pageCount));
    
    when(() => mockFileStorage.storeForDocument(any(), sourcePath))
        .thenAnswer((_) async {});
    
    when(() => mockFileStorage.pathForDocument(any()))
        .thenReturn(storagePath);
        
    // Act
    await pipeline.importFromPath(sourcePath);

    // Assert: Verify FTS table is populated
    // The FTS table `documents_fts` has columns `document_id` (unindexed) and `content`.
    // We search across all indexed columns (i.e. content) using the table name match.
    final result = rawDb.select('SELECT document_id FROM documents_fts WHERE documents_fts MATCH ?', [documentTitle]);
    
    expect(result.length, 1);
  });
}
