import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_archive/infrastructure/sqlite/migrations/migration.dart';
import 'package:personal_archive/infrastructure/sqlite/migrations/migration_runner.dart';
import 'package:personal_archive/infrastructure/sqlite/sqlite_document_repository.dart';
import 'package:personal_archive/src/domain/domain.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

class Sqlite3MigrationDb implements MigrationDb {
  Sqlite3MigrationDb(this._db) {
    _db.execute('PRAGMA foreign_keys = ON');
  }

  final sqlite.Database _db;

  @override
  Future<void> execute(String sql, [List<Object?> parameters = const []]) async {
    _db.execute(sql, parameters);
  }

  @override
  Future<List<Map<String, Object?>>> query(
    String sql, [
    List<Object?> parameters = const [],
  ]) async {
    final result = _db.select(sql, parameters);
    return result
        .map<Map<String, Object?>>((row) => Map<String, Object?>.from(row))
        .toList();
  }

  @override
  Future<T> transaction<T>(Future<T> Function() action) async {
    _db.execute('BEGIN');
    try {
      final result = await action();
      _db.execute('COMMIT');
      return result;
    } catch (e) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }
}

Future<List<Migration>> _loadTestMigrations() async {
  final initSql = await rootBundle
      .loadString('assets/sql/migrations/001_init_core_schema.sql');
  final placesSql =
      await rootBundle.loadString('assets/sql/migrations/002_add_places.sql');
  final documentsAndPagesSql = await rootBundle
      .loadString('assets/sql/migrations/003_add_documents_and_pages.sql');
  final summariesSql =
      await rootBundle.loadString('assets/sql/migrations/004_add_summaries.sql');
  final keywordsSql =
      await rootBundle.loadString('assets/sql/migrations/005_add_keywords.sql');
  final documentKeywordsSql = await rootBundle.loadString(
      'assets/sql/migrations/006_add_document_keywords.sql');
  final embeddingsSql =
      await rootBundle.loadString('assets/sql/migrations/007_add_embeddings.sql');
  final documentsFtsSql = await rootBundle
      .loadString('assets/sql/migrations/008_add_documents_fts.sql');

  return <Migration>[
    Migration(name: '001_init_core_schema', sql: initSql),
    Migration(name: '002_add_places', sql: placesSql),
    Migration(name: '003_add_documents_and_pages', sql: documentsAndPagesSql),
    Migration(name: '004_add_summaries', sql: summariesSql),
    Migration(name: '005_add_keywords', sql: keywordsSql),
    Migration(name: '006_add_document_keywords', sql: documentKeywordsSql),
    Migration(name: '007_add_embeddings', sql: embeddingsSql),
    Migration(name: '008_add_documents_fts', sql: documentsFtsSql),
  ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SqliteDocumentRepository', () {
    late MigrationDb db;
    late SqliteDocumentRepository repo;

    setUp(() async {
      final rawDb = sqlite.sqlite3.openInMemory();
      db = Sqlite3MigrationDb(rawDb);
      final runner = MigrationRunner(
        db: db,
        loadMigrations: _loadTestMigrations,
      );
      await runner.runAll();
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
