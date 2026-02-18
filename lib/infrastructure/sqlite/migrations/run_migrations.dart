import 'migration.dart';
import 'migration_runner.dart';

typedef MigrationLoader = Future<List<Migration>> Function();

/// Convenience entrypoint for running all migrations against a database.
///
/// This is the function that application startup code or a dedicated
/// CLI/test harness should call once it has constructed a [MigrationDb]
/// implementation and a [MigrationLoader] that discovers available
/// migrations (for example from `assets/sql/migrations/`).
Future<void> runMigrations({
  required MigrationDb db,
  required MigrationLoader loadMigrations,
}) async {
  final runner = MigrationRunner(
    db: db,
    loadMigrations: loadMigrations,
  );

  await runner.runAll();
}

