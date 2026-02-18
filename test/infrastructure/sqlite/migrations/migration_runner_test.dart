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

  return <Migration>[
    Migration(
      name: '001_init_core_schema',
      sql: initSql,
    ),
    Migration(
      name: '002_add_documents_and_pages',
      sql: documentsAndPagesSql,
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
  });
}

