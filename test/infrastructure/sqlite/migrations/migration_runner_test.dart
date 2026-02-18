import 'package:flutter_test/flutter_test.dart';
import 'package:personal_archive/infrastructure/sqlite/migrations/migration.dart';
import 'package:personal_archive/infrastructure/sqlite/migrations/migration_runner.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

class Sqlite3MigrationDb implements MigrationDb {
  Sqlite3MigrationDb(this._db);

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
  });
}

