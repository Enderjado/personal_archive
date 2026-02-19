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

  group('SqliteDocumentRepository integration', () {
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

    test('list by status returns only matching documents', () async {
      final now = DateTime.now().toUtc();

      final doc1 = Document(
        id: 'status-doc-1',
        title: 'Imported 1',
        filePath: '/one.pdf',
        status: DocumentStatus.imported,
        createdAt: now,
        updatedAt: now,
        placeId: null,
      );
      final doc2 = Document(
        id: 'status-doc-2',
        title: 'Completed 1',
        filePath: '/two.pdf',
        status: DocumentStatus.completed,
        createdAt: now,
        updatedAt: now,
        placeId: null,
      );
      final doc3 = Document(
        id: 'status-doc-3',
        title: 'Imported 2',
        filePath: '/three.pdf',
        status: DocumentStatus.imported,
        createdAt: now,
        updatedAt: now,
        placeId: null,
      );

      await repo.create(doc1);
      await repo.create(doc2);
      await repo.create(doc3);

      final results =
          await repo.list(status: DocumentStatus.imported);

      final ids = results.map((d) => d.id).toSet();
      expect(ids, {'status-doc-1', 'status-doc-3'});
    });

    test('list by placeId returns only documents for that place', () async {
      final now = DateTime.now().toUtc();

      const placeA = 'place-a';
      const placeB = 'place-b';

      Future<void> insertPlace(String id, String name) async {
        await db.execute(
          '''
          INSERT INTO places (id, name, description, created_at, updated_at)
          VALUES (?, ?, ?, ?, ?)
          ''',
          [
            id,
            name,
            null,
            now.millisecondsSinceEpoch ~/ 1000,
            now.millisecondsSinceEpoch ~/ 1000,
          ],
        );
      }

      await insertPlace(placeA, 'Place A');
      await insertPlace(placeB, 'Place B');

      final docA1 = Document(
        id: 'place-doc-a1',
        title: 'At A1',
        filePath: '/a1.pdf',
        status: DocumentStatus.imported,
        createdAt: now,
        updatedAt: now,
        placeId: placeA,
      );
      final docA2 = Document(
        id: 'place-doc-a2',
        title: 'At A2',
        filePath: '/a2.pdf',
        status: DocumentStatus.imported,
        createdAt: now,
        updatedAt: now,
        placeId: placeA,
      );
      final docB1 = Document(
        id: 'place-doc-b1',
        title: 'At B1',
        filePath: '/b1.pdf',
        status: DocumentStatus.imported,
        createdAt: now,
        updatedAt: now,
        placeId: placeB,
      );

      await repo.create(docA1);
      await repo.create(docA2);
      await repo.create(docB1);

      final results = await repo.list(placeId: placeA);
      final ids = results.map((d) => d.id).toSet();
      expect(ids, {'place-doc-a1', 'place-doc-a2'});
    });

    test('list by createdBetween returns documents in range', () async {
      final now = DateTime.now().toUtc();
      final past = now.subtract(const Duration(days: 2));
      final future = now.add(const Duration(days: 2));

      final docPast = Document(
        id: 'time-doc-past',
        title: 'Past',
        filePath: '/past.pdf',
        status: DocumentStatus.imported,
        createdAt: past,
        updatedAt: past,
        placeId: null,
      );
      final docNow = Document(
        id: 'time-doc-now',
        title: 'Now',
        filePath: '/now.pdf',
        status: DocumentStatus.imported,
        createdAt: now,
        updatedAt: now,
        placeId: null,
      );
      final docFuture = Document(
        id: 'time-doc-future',
        title: 'Future',
        filePath: '/future.pdf',
        status: DocumentStatus.imported,
        createdAt: future,
        updatedAt: future,
        placeId: null,
      );

      await repo.create(docPast);
      await repo.create(docNow);
      await repo.create(docFuture);

      final range = DateTimeRange(
        start: now.subtract(const Duration(days: 1)),
        end: now.add(const Duration(days: 1)),
      );

      final results = await repo.list(createdBetween: range);
      final ids = results.map((d) => d.id).toSet();
      expect(ids, {'time-doc-now'});
    });

    test('findById returns null for non-existent document', () async {
      final result = await repo.findById('does-not-exist');
      expect(result, isNull);
    });
  });
}

