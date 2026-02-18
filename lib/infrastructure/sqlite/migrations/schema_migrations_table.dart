/// SQL definition for the `schema_migrations` metadata table.
///
/// This table tracks which migrations have been applied.
/// - `id`: auto-incremented integer primary key.
/// - `name`: stable migration identifier (e.g. `001_init_core_schema`).
/// - `applied_at`: Unix epoch milliseconds in UTC.
const String createSchemaMigrationsTableSql = '''
CREATE TABLE IF NOT EXISTS schema_migrations (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL UNIQUE,
  applied_at INTEGER NOT NULL
);
''';

/// Example of the expected migration name format.
const String exampleMigrationName = '001_init_core_schema';

