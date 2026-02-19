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

  group('SqliteSummaryRepository', () {
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
  });
}
