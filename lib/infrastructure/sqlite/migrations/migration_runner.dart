import 'package:personal_archive/infrastructure/sqlite/storage_logging.dart';

import 'migration.dart';
import 'schema_migrations_table.dart';

/// Minimal abstraction over the underlying SQLite client used for migrations.
///
/// This keeps the migration runner independent of a specific package
/// (e.g. `sqflite`, `sqlite3`) while still being easy to adapt.
abstract class MigrationDb {
  /// Execute a single SQL statement with optional positional parameters.
  Future<void> execute(String sql, [List<Object?> parameters]);

  /// Run a `SELECT` query and return raw rows.
  Future<List<Map<String, Object?>>> query(String sql, [List<Object?> parameters]);

  /// Run [action] inside a transaction.
  ///
  /// Implementations are responsible for beginning, committing, and
  /// rolling back the transaction as needed.
  Future<T> transaction<T>(Future<T> Function() action);
}

/// Coordinates applying schema migrations against a SQLite database.
class MigrationRunner {
  MigrationRunner({
    required this.db,
    required this.loadMigrations,
    StorageLogger logger = const NoOpStorageLogger(),
  }) : _logger = logger;

  /// Database adapter used by the runner.
  final MigrationDb db;

  /// Logger used for recording migration lifecycle events.
  final StorageLogger _logger;

  /// Function that returns the full set of known migrations.
  ///
  /// A later task will wire this up to `.sql` files under
  /// `assets/sql/migrations/`.
  final Future<List<Migration>> Function() loadMigrations;

  /// Ensures the `schema_migrations` metadata table exists.
  Future<void> ensureMetadataTable() async {
    await db.execute(createSchemaMigrationsTableSql, const []);
  }

  /// Loads the set of already applied migration names.
  Future<Set<String>> _loadAppliedMigrationNames() async {
    await ensureMetadataTable();
    final rows = await db.query(
      'SELECT name FROM schema_migrations',
      const [],
    );
    return rows
        .map((row) => row['name'])
        .whereType<String>()
        .toSet();
  }

  Future<void> _recordAppliedMigration(String name) async {
    final appliedAt = DateTime.now().toUtc().millisecondsSinceEpoch;
    await db.execute(
      'INSERT INTO schema_migrations (name, applied_at) VALUES (?, ?)',
      [name, appliedAt],
    );
  }

  /// Runs all known migrations inside a single transaction.
  ///
  /// Idempotency and recording of applied migrations are handled in
  /// this method.
  Future<void> runAll() async {
    final migrations = await loadMigrations();
    final ordered = sortMigrationsByName(migrations);
    final applied = await _loadAppliedMigrationNames();

    await db.transaction<void>(() async {
      for (final migration in ordered) {
        if (applied.contains(migration.name)) {
          continue;
        }

        final stopwatch = Stopwatch()..start();

        _logger.logWrite(
          operation: 'migration_start:${migration.name}',
          table: 'migrations',
          recordCount: 0,
          duration: Duration.zero,
        );

        try {
          await timeWriteOperation<void>(
            logger: _logger,
            operation: 'apply_migration_sql:${migration.name}',
            table: 'migrations',
            recordCount: 1,
            action: () => db.execute(migration.sql, const []),
          );

          await timeWriteOperation<void>(
            logger: _logger,
            operation: 'record_applied_migration:${migration.name}',
            table: 'schema_migrations',
            recordCount: 1,
            action: () => _recordAppliedMigration(migration.name),
          );

          stopwatch.stop();

          _logger.logWrite(
            operation: 'migration_success:${migration.name}',
            table: 'migrations',
            recordCount: 1,
            duration: stopwatch.elapsed,
          );
        } catch (e) {
          stopwatch.stop();

          _logger.logWrite(
            operation: 'migration_error:${migration.name}',
            table: 'migrations',
            recordCount: 0,
            duration: stopwatch.elapsed,
          );

          rethrow;
        }
      }
    });
  }
}

