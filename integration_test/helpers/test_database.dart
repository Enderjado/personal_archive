import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:personal_archive/infrastructure/sqlite/migrations/migration.dart';
import 'package:personal_archive/infrastructure/sqlite/migrations/migration_runner.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

/// Testing implementation of [MigrationDb] that uses package:sqlite3.
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

/// Result of setting up the test database.
class TestDatabaseResult {
  final sqlite.Database db;
  final MigrationDb migrationDb;

  TestDatabaseResult(this.db, this.migrationDb);
}

/// Helper function to load migrations from asset files.
Future<List<Migration>> loadMigrationsFromAssets() async {
  final migrations = <Migration>[];
  
  // List of known migration files in order.
  const migrationFiles = [
    '001_init_core_schema.sql',
    '002_add_places.sql',
    '003_add_documents_and_pages.sql',
    '004_add_summaries.sql',
    '005_add_keywords.sql',
    '006_add_document_keywords.sql',
    '007_add_embeddings.sql',
    '008_add_documents_fts.sql',
  ];

  for (final filename in migrationFiles) {
    try {
      final sql = await rootBundle.loadString('assets/sql/migrations/$filename');
      
      // Use the filename (without extension) as the migration name.
      // This preserves the ordering (e.g. "001_init_core_schema").
      final name = filename.replaceAll('.sql', '');
      
      migrations.add(Migration(
        name: name,
        sql: sql,
      ));
    } catch (e) {
      print('Error loading migration $filename: $e');
      rethrow;
    }
  }
  
  return migrations;
}

/// Sets up an in-memory database with all migrations applied.
Future<TestDatabaseResult> setupTestDatabase() async {
  final db = sqlite.sqlite3.openInMemory();
  final migrationDb = Sqlite3MigrationDb(db);
  
  final runner = MigrationRunner(
    db: migrationDb,
    loadMigrations: loadMigrationsFromAssets,
  );
  
  await runner.ensureMetadataTable();
  await runner.runAll(); 
  
  return TestDatabaseResult(db, migrationDb);
}

