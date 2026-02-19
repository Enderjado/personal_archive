import 'package:flutter_test/flutter_test.dart';
import 'package:personal_archive/infrastructure/sqlite/migrations/migration_runner.dart'
    show MigrationDb;
import 'package:personal_archive/infrastructure/sqlite/sqlite_summary_repository.dart';
import 'package:personal_archive/infrastructure/sqlite/storage_logging.dart';
import 'package:personal_archive/src/domain/domain.dart';
import 'sqlite_test_harness.dart';

class _TestStorageLogger implements StorageLogger {
  final List<String> writeEvents = <String>[];
  final List<String> readEvents = <String>[];

  @override
  void logWrite({
    required String operation,
    required String table,
    required int recordCount,
    required Duration duration,
  }) {
    writeEvents.add(operation);
  }

  @override
  void logRead({
    required String operation,
    required String table,
    required Duration duration,
  }) {
    readEvents.add(operation);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SqliteSummaryRepository', () {
    late MigrationDb db;
    late SqliteSummaryRepository repo;

    setUp(() async {
      db = await createMigratedTestDb();
      repo = SqliteSummaryRepository(db);
    });

    test('upsert then findByDocumentId returns summary with correct fields',
        () async {
      const documentId = 'doc-with-summary';
      await db.execute(
        '''
        INSERT INTO documents (
          id, title, file_path, status, confidence_score,
          place_id, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        [
          documentId,
          'Doc Title',
          '/path/to/doc.pdf',
          DocumentStatus.imported.name,
          0.9,
          null,
          0,
          0,
        ],
      );

      final createdAt = DateTime.utc(2025, 2, 19, 12, 0, 0);
      final summary = Summary(
        documentId: documentId,
        text: 'A short summary of the document.',
        modelVersion: 'qwen2.5-0.5b',
        createdAt: createdAt,
      );
      await repo.upsert(summary);

      final found = await repo.findByDocumentId(documentId);
      expect(found, isNotNull);
      expect(found!.documentId, documentId);
      expect(found.text, 'A short summary of the document.');
      expect(found.modelVersion, 'qwen2.5-0.5b');
      expect(found.createdAt, createdAt);
    });

    test('second upsert updates existing summary', () async {
      const documentId = 'doc-update-summary';
      await db.execute(
        '''
        INSERT INTO documents (
          id, title, file_path, status, confidence_score,
          place_id, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        [
          documentId,
          'Doc Title',
          '/path/to/doc.pdf',
          DocumentStatus.imported.name,
          null,
          null,
          0,
          0,
        ],
      );

      await repo.upsert(Summary(
        documentId: documentId,
        text: 'First summary',
        modelVersion: 'v1',
        createdAt: DateTime.utc(2025, 1, 1),
      ));
      await repo.upsert(Summary(
        documentId: documentId,
        text: 'Updated summary text',
        modelVersion: 'v2',
        createdAt: DateTime.utc(2025, 2, 19),
      ));

      final found = await repo.findByDocumentId(documentId);
      expect(found, isNotNull);
      expect(found!.text, 'Updated summary text');
      expect(found.modelVersion, 'v2');
      expect(found.createdAt, DateTime.utc(2025, 2, 19));
    });

    test('findByDocumentId returns null when document has no summary',
        () async {
      const documentId = 'doc-no-summary';
      await db.execute(
        '''
        INSERT INTO documents (
          id, title, file_path, status, confidence_score,
          place_id, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        [
          documentId,
          'Doc Without Summary',
          '/path/to/other.pdf',
          DocumentStatus.imported.name,
          null,
          null,
          0,
          0,
        ],
      );

      final found = await repo.findByDocumentId(documentId);
      expect(found, isNull);
    });

    test('works correctly when storage logging is enabled', () async {
      const documentId = 'doc-with-logged-summary';
      await db.execute(
        '''
        INSERT INTO documents (
          id, title, file_path, status, confidence_score,
          place_id, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        [
          documentId,
          'Logged Doc',
          '/path/to/logged.pdf',
          DocumentStatus.imported.name,
          null,
          null,
          0,
          0,
        ],
      );

      final logger = _TestStorageLogger();
      final loggedRepo = SqliteSummaryRepository(
        db,
        logger: logger,
        slowReadThreshold: Duration.zero,
      );

      final createdAt = DateTime.utc(2025, 2, 19, 13, 0, 0);
      final summary = Summary(
        documentId: documentId,
        text: 'Summary text with logging enabled.',
        modelVersion: 'qwen2.5-0.5b',
        createdAt: createdAt,
      );

      await loggedRepo.upsert(summary);
      final found = await loggedRepo.findByDocumentId(documentId);

      expect(found, isNotNull);
      expect(found!.text, 'Summary text with logging enabled.');

      // Logging should not interfere with normal repository operation and should record events.
      expect(logger.writeEvents, isNotEmpty);
      expect(logger.readEvents, isNotEmpty);
    });
  });
}
