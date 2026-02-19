import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_archive/infrastructure/sqlite/migrations/migration.dart';
import 'package:personal_archive/infrastructure/sqlite/migrations/migration_runner.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

class Sqlite3MigrationDb implements MigrationDb {
  Sqlite3MigrationDb(this._db) {
    // Ensure foreign key enforcement is enabled for all connections.
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
  final documentsAndPagesSql =
      await rootBundle.loadString('assets/sql/migrations/002_add_documents_and_pages.sql');
  final summariesSql =
      await rootBundle.loadString('assets/sql/migrations/003_add_summaries.sql');
  final keywordsSql =
      await rootBundle.loadString('assets/sql/migrations/004_add_keywords.sql');
  final documentKeywordsSql = await rootBundle.loadString(
      'assets/sql/migrations/005_add_document_keywords.sql');
  final embeddingsSql =
      await rootBundle.loadString('assets/sql/migrations/006_add_embeddings.sql');

  return <Migration>[
    Migration(
      name: '001_init_core_schema',
      sql: initSql,
    ),
    Migration(
      name: '002_add_documents_and_pages',
      sql: documentsAndPagesSql,
    ),
    Migration(
      name: '003_add_summaries',
      sql: summariesSql,
    ),
    Migration(
      name: '004_add_keywords',
      sql: keywordsSql,
    ),
    Migration(
      name: '005_add_document_keywords',
      sql: documentKeywordsSql,
    ),
    Migration(
      name: '006_add_embeddings',
      sql: embeddingsSql,
    ),
  ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('MigrationRunner', () {
    test('enables foreign key enforcement', () async {
      final rawDb = sqlite.sqlite3.openInMemory();
      final db = Sqlite3MigrationDb(rawDb);

      final pragmaRows = await db.query('PRAGMA foreign_keys');
      expect(pragmaRows, isNotEmpty);
      expect(pragmaRows.single['foreign_keys'], 1);
    });

    test('creates schema_migrations and records applied migrations', () async {
      final db = Sqlite3MigrationDb(sqlite.sqlite3.openInMemory());

      final migrations = <Migration>[
        const Migration(
          name: '001_init_core_schema',
          sql: '',
        ),
      ];

      final runner = MigrationRunner(
        db: db,
        loadMigrations: () async => migrations,
      );

      await runner.runAll();

      // schema_migrations table exists
      final pragmaResult = await db.query(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'schema_migrations'",
      );
      expect(pragmaResult, isNotEmpty);

      // all known migrations are recorded as applied
      final appliedRows = await db.query(
        'SELECT name FROM schema_migrations',
      );
      final appliedNames = appliedRows
          .map((row) => row['name'])
          .whereType<String>()
          .toSet();

      expect(appliedNames, contains('001_init_core_schema'));
    });

    test('is idempotent when run multiple times', () async {
      final db = Sqlite3MigrationDb(sqlite.sqlite3.openInMemory());

      final migrations = <Migration>[
        const Migration(
          name: '001_init_core_schema',
          sql: '',
        ),
      ];

      final runner = MigrationRunner(
        db: db,
        loadMigrations: () async => migrations,
      );

      await runner.runAll();
      await runner.runAll();

      final appliedRows = await db.query(
        'SELECT name FROM schema_migrations',
      );
      final appliedNames = appliedRows
          .map((row) => row['name'])
          .whereType<String>()
          .toList();

      expect(appliedNames.length, 1);
      expect(appliedNames.single, '001_init_core_schema');
    });

    test('applies documents and pages schema and supports basic operations',
        () async {
      final db = Sqlite3MigrationDb(sqlite.sqlite3.openInMemory());

      final runner = MigrationRunner(
        db: db,
        loadMigrations: _loadTestMigrations,
      );

      await runner.runAll();

      // Insert a document row.
      await db.execute(
        '''
INSERT INTO documents (
  id, title, file_path, status, confidence_score, place_id, created_at, updated_at
) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
''',
        [
          'doc-1',
          'Test Document',
          '/tmp/test.pdf',
          'imported',
          null,
          null,
          1,
          2,
        ],
      );

      // Insert multiple page rows for the document.
      await db.execute(
        '''
INSERT INTO pages (
  id, document_id, page_number, raw_text, processed_text, ocr_confidence
) VALUES (?, ?, ?, ?, ?, ?)
''',
        [
          'page-1',
          'doc-1',
          1,
          'raw 1',
          'processed 1',
          0.9,
        ],
      );

      await db.execute(
        '''
INSERT INTO pages (
  id, document_id, page_number, raw_text, processed_text, ocr_confidence
) VALUES (?, ?, ?, ?, ?, ?)
''',
        [
          'page-2',
          'doc-1',
          2,
          'raw 2',
          'processed 2',
          0.8,
        ],
      );

      // Read back and verify.
      final documents = await db.query('SELECT * FROM documents', const []);
      expect(documents, hasLength(1));

      final pages = await db.query(
        'SELECT * FROM pages WHERE document_id = ? ORDER BY page_number',
        ['doc-1'],
      );
      expect(pages, hasLength(2));
      expect(pages.first['page_number'], 1);
      expect(pages.last['page_number'], 2);

      // Uniqueness constraint on (document_id, page_number) should be enforced.
      await expectLater(
        db.execute(
          '''
INSERT INTO pages (
  id, document_id, page_number, raw_text, processed_text, ocr_confidence
) VALUES (?, ?, ?, ?, ?, ?)
''',
          [
            'page-duplicate',
            'doc-1',
            1, // duplicate page_number for same document_id
            'raw dup',
            'processed dup',
            0.7,
          ],
        ),
        throwsA(isA<sqlite.SqliteException>()),
      );

      // Deleting the document should cascade to its pages.
      await db.execute(
        'DELETE FROM documents WHERE id = ?',
        ['doc-1'],
      );

      final remainingPages = await db.query(
        'SELECT * FROM pages WHERE document_id = ?',
        ['doc-1'],
      );
      expect(remainingPages, isEmpty);
    });

    test('supports summaries, keywords, and document_keywords with referential integrity',
        () async {
      final db = Sqlite3MigrationDb(sqlite.sqlite3.openInMemory());

      final runner = MigrationRunner(
        db: db,
        loadMigrations: _loadTestMigrations,
      );

      await runner.runAll();

      const now = 1000;

      // Insert a place and a document.
      await db.execute(
        '''
INSERT INTO places (id, name, description, created_at, updated_at)
VALUES (?, ?, ?, ?, ?)
''',
        ['place-1', 'Archive', null, now, now],
      );

      await db.execute(
        '''
INSERT INTO documents (
  id, title, file_path, status, confidence_score, place_id, created_at, updated_at
) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
''',
        ['doc-1', 'Test Doc', '/path/doc.pdf', 'completed', 0.9, 'place-1', now, now],
      );

      // Insert summary (1:1 with document).
      await db.execute(
        '''
INSERT INTO summaries (document_id, text, model_version, created_at)
VALUES (?, ?, ?, ?)
''',
        ['doc-1', 'A short summary.', 'qwen2.5-0.5b', now],
      );

      // Insert keywords.
      await db.execute(
        '''
INSERT INTO keywords (id, value, type, global_frequency, created_at)
VALUES (?, ?, ?, ?, ?)
''',
        ['kw-1', 'tax', 'topic', 0, now],
      );
      await db.execute(
        '''
INSERT INTO keywords (id, value, type, global_frequency, created_at)
VALUES (?, ?, ?, ?, ?)
''',
        ['kw-2', '2024', 'date', 0, now],
      );

      // Link document to keywords via document_keywords.
      await db.execute(
        '''
INSERT INTO document_keywords (id, document_id, keyword_id, weight, confidence, source)
VALUES (?, ?, ?, ?, ?, ?)
''',
        ['dk-1', 'doc-1', 'kw-1', 0.8, 0.9, 'llm_initial'],
      );
      await db.execute(
        '''
INSERT INTO document_keywords (id, document_id, keyword_id, weight, confidence, source)
VALUES (?, ?, ?, ?, ?, ?)
''',
        ['dk-2', 'doc-1', 'kw-2', 0.5, 0.85, null],
      );

      // Query back and verify.
      final summaries = await db.query(
        'SELECT * FROM summaries WHERE document_id = ?',
        ['doc-1'],
      );
      expect(summaries, hasLength(1));
      expect(summaries.single['text'], 'A short summary.');
      expect(summaries.single['model_version'], 'qwen2.5-0.5b');

      final keywords = await db.query('SELECT * FROM keywords ORDER BY id', const []);
      expect(keywords, hasLength(2));

      final docKeywords = await db.query(
        'SELECT * FROM document_keywords WHERE document_id = ? ORDER BY keyword_id',
        ['doc-1'],
      );
      expect(docKeywords, hasLength(2));
      expect(docKeywords.first['weight'], 0.8);
      expect(docKeywords.first['confidence'], 0.9);

      // Unique (document_id, keyword_id) rejects duplicate.
      await expectLater(
        db.execute(
          '''
INSERT INTO document_keywords (id, document_id, keyword_id, weight, confidence)
VALUES (?, ?, ?, ?, ?)
''',
          ['dk-dup', 'doc-1', 'kw-1', 0.1, 0.1],
        ),
        throwsA(isA<sqlite.SqliteException>()),
      );

      // Deleting document cascades to summaries and document_keywords.
      await db.execute('DELETE FROM documents WHERE id = ?', ['doc-1']);

      final summariesAfter = await db.query('SELECT * FROM summaries', const []);
      expect(summariesAfter, isEmpty);

      final docKeywordsAfter = await db.query(
        'SELECT * FROM document_keywords WHERE document_id = ?',
        ['doc-1'],
      );
      expect(docKeywordsAfter, isEmpty);

      // Keywords remain (reusable).
      final keywordsAfter = await db.query('SELECT * FROM keywords', const []);
      expect(keywordsAfter, hasLength(2));
    });

    test('supports embeddings insert and read-back with cascade on document delete',
        () async {
      final db = Sqlite3MigrationDb(sqlite.sqlite3.openInMemory());

      final runner = MigrationRunner(
        db: db,
        loadMigrations: _loadTestMigrations,
      );

      await runner.runAll();

      const now = 2000;

      // Insert a document.
      await db.execute(
        '''
INSERT INTO documents (
  id, title, file_path, status, confidence_score, place_id, created_at, updated_at
) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
''',
        ['doc-emb', 'Embedding Test', '/path/emb.pdf', 'completed', null, null, now, now],
      );

      // Insert a dummy embedding (JSON array of floats).
      const vectorJson = '[0.1,-0.2,0.3]';
      await db.execute(
        '''
INSERT INTO embeddings (document_id, vector, model_version, created_at)
VALUES (?, ?, ?, ?)
''',
        ['doc-emb', vectorJson, 'test-model-v1', now],
      );

      // Read back and verify.
      final rows = await db.query(
        'SELECT * FROM embeddings WHERE document_id = ?',
        ['doc-emb'],
      );
      expect(rows, hasLength(1));
      expect(rows.single['document_id'], 'doc-emb');
      expect(rows.single['vector'], vectorJson);
      expect(rows.single['model_version'], 'test-model-v1');
      expect(rows.single['created_at'], now);

      // Deleting document cascades to embeddings.
      await db.execute('DELETE FROM documents WHERE id = ?', ['doc-emb']);
      final embeddingsAfter =
          await db.query('SELECT * FROM embeddings WHERE document_id = ?', ['doc-emb']);
      expect(embeddingsAfter, isEmpty);
    });
  });
}

