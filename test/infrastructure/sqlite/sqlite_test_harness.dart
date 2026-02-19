import 'package:flutter/services.dart' show rootBundle;
import 'package:personal_archive/infrastructure/sqlite/migrations/migration.dart';
import 'package:personal_archive/infrastructure/sqlite/migrations/migration_runner.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

/// Minimal [MigrationDb] implementation backed by `package:sqlite3`.
class Sqlite3MigrationDb implements MigrationDb {
  Sqlite3MigrationDb(this._db) {
    // Ensure foreign key enforcement is enabled for all connections.
    _db.execute('PRAGMA foreign_keys = ON');
  }

  final sqlite.Database _db;

  sqlite.Database get rawDb => _db;

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

/// Loads the full set of SQL migrations used in storage-layer tests.
Future<List<Migration>> loadTestMigrations() async {
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

/// Helper for creating a migrated in-memory SQLite database for tests.
///
/// Typical usage in tests:
/// ```dart
/// late Sqlite3MigrationDb db;
///
/// setUp(() async {
///   db = await createMigratedTestDb();
///   // construct repositories with [db] here
/// });
/// ```
Future<Sqlite3MigrationDb> createMigratedTestDb({
  Future<List<Migration>> Function()? loadMigrations,
}) async {
  final rawDb = sqlite.sqlite3.openInMemory();
  final db = Sqlite3MigrationDb(rawDb);

  final runner = MigrationRunner(
    db: db,
    loadMigrations: loadMigrations ?? loadTestMigrations,
  );

  await runner.runAll();
  return db;
}

