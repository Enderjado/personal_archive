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

void main() {
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
  });
}

