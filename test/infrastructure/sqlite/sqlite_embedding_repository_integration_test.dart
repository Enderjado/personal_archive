import 'package:flutter_test/flutter_test.dart';
import 'package:personal_archive/infrastructure/sqlite/sqlite_embedding_repository.dart';
import 'package:personal_archive/src/domain/domain.dart';
import 'package:personal_archive/infrastructure/sqlite/migrations/migration_runner.dart'
    show MigrationDb;
import 'sqlite_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SqliteEmbeddingRepository integration', () {
    late MigrationDb db;
    late SqliteEmbeddingRepository repo;

    setUp(() async {
      db = await createMigratedTestDb();
      repo = SqliteEmbeddingRepository(db);
    });

    test(
      'full migration + insert document + upsert embedding + findByDocumentId returns embedding',
      () async {
        const documentId = 'doc-full-embedding-cycle';
        final now = DateTime.utc(2025, 2, 19, 14, 30, 0);
        final epoch = now.millisecondsSinceEpoch;

        await db.execute(
          '''
          INSERT INTO documents (
            id, title, file_path, status, confidence_score,
            place_id, created_at, updated_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
          ''',
          [
            documentId,
            'Full Cycle Doc',
            '/path/full.pdf',
            DocumentStatus.imported.name,
            0.85,
            null,
            epoch,
            epoch,
          ],
        );

        final embedding = Embedding(
          documentId: documentId,
          vector: <double>[0.1, -0.2, 0.3, 0.4],
          modelVersion: 'embed-model-v1',
          createdAt: now,
        );
        await repo.upsert(embedding);

        final found = await repo.findByDocumentId(documentId);
        expect(found, isNotNull);
        expect(found!.documentId, documentId);
        expect(found.vector, <double>[0.1, -0.2, 0.3, 0.4]);
        expect(found.modelVersion, 'embed-model-v1');
        expect(found.createdAt, now);
      },
    );

    test('upsert with non-existent documentId throws StorageConstraintError',
        () async {
      final embedding = Embedding(
        documentId: 'non-existent-doc',
        vector: <double>[0.5, 0.6],
        modelVersion: 'embed-model-v1',
        createdAt: DateTime.utc(2025, 2, 19),
      );

      expect(
        () => repo.upsert(embedding),
        throwsA(isA<StorageConstraintError>()),
      );
    });

    test('findByDocumentId for document with no embedding returns null',
        () async {
      const documentId = 'doc-no-embedding';
      final epoch = DateTime.utc(2025, 2, 19).millisecondsSinceEpoch;

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
          '/path/nosummary.pdf',
          DocumentStatus.imported.name,
          null,
          null,
          epoch,
          epoch,
        ],
      );

      final result = await repo.findByDocumentId(documentId);

      expect(result, isNull);
    });
  });
}

