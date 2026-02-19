import 'package:flutter_test/flutter_test.dart';
import 'package:personal_archive/infrastructure/sqlite/sqlite_embedding_repository.dart';
import 'package:personal_archive/src/domain/domain.dart';
import 'package:personal_archive/infrastructure/sqlite/migrations/migration_runner.dart'
    show MigrationDb;
import 'sqlite_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SqliteEmbeddingRepository', () {
    late MigrationDb db;
    late SqliteEmbeddingRepository repo;

    setUp(() async {
      db = await createMigratedTestDb();
      repo = SqliteEmbeddingRepository(db);
    });

    test('upsert then findByDocumentId returns embedding with correct fields',
        () async {
      const documentId = 'doc-with-embedding';

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
      final embedding = Embedding(
        documentId: documentId,
        vector: <double>[0.1, -0.2, 0.3],
        modelVersion: 'embed-model-v1',
        createdAt: createdAt,
      );

      await repo.upsert(embedding);

      final found = await repo.findByDocumentId(documentId);
      expect(found, isNotNull);
      expect(found!.documentId, documentId);
      expect(found.vector, <double>[0.1, -0.2, 0.3]);
      expect(found.modelVersion, 'embed-model-v1');
      expect(found.createdAt, createdAt);
    });

    test('findByDocumentId returns null when document has no embedding',
        () async {
      const documentId = 'doc-no-embedding';

      await db.execute(
        '''
        INSERT INTO documents (
          id, title, file_path, status, confidence_score,
          place_id, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        [
          documentId,
          'Doc Without Embedding',
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
  });
}

