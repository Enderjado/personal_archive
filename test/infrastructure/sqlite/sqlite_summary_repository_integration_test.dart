import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_archive/infrastructure/sqlite/migrations/migration.dart';
import 'package:personal_archive/infrastructure/sqlite/migrations/migration_runner.dart';
import 'package:personal_archive/infrastructure/sqlite/sqlite_summary_repository.dart';
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
  final initSql =
      await rootBundle.loadString('assets/sql/migrations/001_init_core_schema.sql');
  final placesSql =
      await rootBundle.loadString('assets/sql/migrations/002_add_places.sql');
  final documentsAndPagesSql = await rootBundle
      .loadString('assets/sql/migrations/003_add_documents_and_pages.sql');
  final summariesSql =
      await rootBundle.loadString('assets/sql/migrations/004_add_summaries.sql');
  final keywordsSql =
      await rootBundle.loadString('assets/sql/migrations/005_add_keywords.sql');
  final documentKeywordsSql = await rootBundle
      .loadString('assets/sql/migrations/006_add_document_keywords.sql');
  final embeddingsSql =
      await rootBundle.loadString('assets/sql/migrations/007_add_embeddings.sql');
  final documentsFtsSql =
      await rootBundle.loadString('assets/sql/migrations/008_add_documents_fts.sql');

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

  group('SqliteSummaryRepository integration', () {
    late MigrationDb db;
    late SqliteSummaryRepository repo;

    setUp(() async {
      final rawDb = sqlite.sqlite3.openInMemory();
      db = Sqlite3MigrationDb(rawDb);
      final runner = MigrationRunner(
        db: db,
        loadMigrations: _loadTestMigrations,
      );
      await runner.runAll();
      repo = SqliteSummaryRepository(db);
    });

    test(
      'full migration + insert document + upsert summary + findByDocumentId returns summary',
      () async {
        const documentId = 'doc-full-cycle';
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

        const summaryText = 'Summary survives migration + insert + query cycle.';
        const modelVersion = 'qwen2.5-0.5b';
        final summary = Summary(
          documentId: documentId,
          text: summaryText,
          modelVersion: modelVersion,
          createdAt: now,
        );
        await repo.upsert(summary);

        final found = await repo.findByDocumentId(documentId);
        expect(found, isNotNull);
        expect(found!.documentId, documentId);
        expect(found.text, summaryText);
        expect(found.modelVersion, modelVersion);
        expect(found.createdAt, now);
      },
    );

    test('upsert with non-existent documentId throws StorageConstraintError',
        () async {
      final summary = Summary(
        documentId: 'non-existent-doc',
        text: 'Orphan summary',
        modelVersion: 'v1',
        createdAt: DateTime.utc(2025, 2, 19),
      );

      expect(
        () => repo.upsert(summary),
        throwsA(isA<StorageConstraintError>()),
      );
    });

    test('findByDocumentId for document with no summary returns null', () async {
      const documentId = 'doc-no-summary';
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
          'Doc Without Summary',
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
