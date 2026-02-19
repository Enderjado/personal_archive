import 'package:flutter_test/flutter_test.dart';
import 'package:personal_archive/infrastructure/sqlite/sqlite_document_repository.dart';
import 'package:personal_archive/src/domain/domain.dart';
import 'package:personal_archive/infrastructure/sqlite/migrations/migration_runner.dart'
    show MigrationDb;
import 'sqlite_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SqliteDocumentRepository', () {
    late MigrationDb db;
    late SqliteDocumentRepository repo;

    setUp(() async {
      db = await createMigratedTestDb();
      repo = SqliteDocumentRepository(db);
    });

    test('create then findById returns document with matching fields', () async {
      final now = DateTime.now().toUtc();
      final draft = Document(
        id: 'doc-create-test',
        title: 'My Title',
        filePath: '/path/to/file.pdf',
        status: DocumentStatus.imported,
        confidenceScore: 0.95,
        createdAt: now,
        updatedAt: now,
        placeId: null,
      );

      await repo.create(draft);
      final found = await repo.findById(draft.id);

      expect(found, isNotNull);
      expect(found!.id, draft.id);
      expect(found.title, draft.title);
      expect(found.filePath, draft.filePath);
      expect(found.status, draft.status);
      expect(found.confidenceScore, draft.confidenceScore);
      expect(found.placeId, draft.placeId);
      expect(found.createdAt.toUtc().millisecondsSinceEpoch ~/ 1000,
          draft.createdAt.toUtc().millisecondsSinceEpoch ~/ 1000);
      expect(found.updatedAt.toUtc().millisecondsSinceEpoch ~/ 1000,
          draft.updatedAt.toUtc().millisecondsSinceEpoch ~/ 1000);
    });

    test('update then findById returns updated status and place_id', () async {
      final now = DateTime.now().toUtc();
      const placeId = 'place-update-test';

      await db.execute(
        '''
        INSERT INTO places (id, name, description, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?)
        ''',
        [placeId, 'Test Place', null, now.millisecondsSinceEpoch ~/ 1000, now.millisecondsSinceEpoch ~/ 1000],
      );

      final draft = Document(
        id: 'doc-update-test',
        title: 'Original Title',
        filePath: '/original.pdf',
        status: DocumentStatus.imported,
        createdAt: now,
        updatedAt: now,
        placeId: null,
      );
      await repo.create(draft);

      final updated = draft.copyWith(
        title: 'Updated Title',
        status: DocumentStatus.completed,
        placeId: placeId,
        updatedAt: now.add(const Duration(hours: 1)),
      );
      await repo.update(updated);

      final found = await repo.findById(draft.id);
      expect(found, isNotNull);
      expect(found!.title, 'Updated Title');
      expect(found.status, DocumentStatus.completed);
      expect(found.placeId, placeId);
      expect(found.updatedAt.toUtc().millisecondsSinceEpoch ~/ 1000,
          updated.updatedAt.toUtc().millisecondsSinceEpoch ~/ 1000);
    });
  });
}
