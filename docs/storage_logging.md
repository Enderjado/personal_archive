# Storage-Layer Logging & Metrics Hooks

The storage layer uses a small, pluggable logging abstraction to make important SQLite operations observable without coupling repositories to a specific logging framework.

This document describes what is logged, how it works, and how to configure it in development.

---

## Overview

Storage observability focuses on three areas:

- **Repository writes**: inserts, updates, and bulk operations that change data.
- **Slow reads**: queries that exceed a configurable latency threshold.
- **Migrations**: the lifecycle of schema migrations, including success and failure.

All of this is wired through `StorageLogger` in the SQLite infrastructure layer.

---

## StorageLogger abstraction

The core interface lives in `lib/infrastructure/sqlite/storage_logging.dart`:

- **`StorageLogger`**: defines
  - `logWrite(operation, table, recordCount, duration)`
  - `logRead(operation, table, duration)`
- **`NoOpStorageLogger`**: a default implementation that does nothing; used when logging is not configured.
- **Timing helpers**:
  - `timeWriteOperation` wraps an async write and reports its duration via `logWrite`.
  - `timeReadOperation` wraps an async read and, if it exceeds a threshold, reports its duration via `logRead`.

These helpers are used by repositories and the migration runner so that instrumentation is centralized and consistent.

---

## Repository logging behavior

Each SQLite-backed repository accepts an optional `StorageLogger` and a `slowReadThreshold`:

- Constructors have the shape:
  - `SqliteXRepository(MigrationDb db, { StorageLogger logger = const NoOpStorageLogger(), Duration slowReadThreshold = const Duration(milliseconds: 75), })`
- **Write operations** (such as `upsert`, `create`, bulk `insertAll`) are wrapped in `timeWriteOperation`, which logs:
  - `operation`: a short, descriptive operation name (e.g. `create_document`, `upsert_summary`).
  - `table`: the primary table being modified (e.g. `documents`, `summaries`).
  - `recordCount`: number of rows affected or attempted.
  - `duration`: how long the operation took.
- **Read operations** that are likely to be performance-sensitive are wrapped in `timeReadOperation`, which:
  - Measures query duration.
  - Emits a `logRead` event only when `duration >= slowReadThreshold`.

In development you can:

- Provide a concrete `StorageLogger` that prints to the console or forwards to a logging package.
- Lower `slowReadThreshold` (even to `Duration.zero`) to surface all reads while debugging.

---

## Migration logging behavior

`MigrationRunner` in `lib/infrastructure/sqlite/migrations/migration_runner.dart` also accepts an optional `StorageLogger`:

- Constructor:
  - `MigrationRunner({ required MigrationDb db, required Future<List<Migration>> Function() loadMigrations, StorageLogger logger = const NoOpStorageLogger(), })`
- For each unapplied migration, the runner:
  - Logs a **start** event: `migration_start:<name>`.
  - Uses `timeWriteOperation` to:
    - Apply the migration SQL to the database.
    - Record the migration in `schema_migrations`.
  - On success, logs a **success** event: `migration_success:<name>` with the end-to-end duration.
  - On error, logs a **failure** event: `migration_error:<name>` with the elapsed time, then rethrows so the transaction can roll back.

This makes it easier to see which migration failed and roughly how long each one took.

---

## Development usage

To observe storage behavior during development:

1. **Implement a simple logger**, for example in your application layer:

   ```dart
   class ConsoleStorageLogger implements StorageLogger {
     @override
     void logWrite({
       required String operation,
       required String table,
       required int recordCount,
       required Duration duration,
     }) {
       // Replace with your preferred logging framework if needed.
       // e.g. debugPrint or package:logging.
       // debugPrint('[WRITE] $operation table=$table count=$recordCount duration=${duration.inMilliseconds}ms');
     }

     @override
     void logRead({
       required String operation,
       required String table,
       required Duration duration,
     }) {
       // debugPrint('[READ] $operation table=$table duration=${duration.inMilliseconds}ms');
     }
   }
   ```

2. **Pass the logger into infrastructure components** when wiring them up:

   ```dart
   final storageLogger = ConsoleStorageLogger();

   final documentRepo = SqliteDocumentRepository(
     migrationDb,
     logger: storageLogger,
   );

   final migrationRunner = MigrationRunner(
     db: migrationDb,
     loadMigrations: loadMigrations,
     logger: storageLogger,
   );
   ```

3. **Tune the slow-read threshold** when investigating performance:
   - Use a lower threshold (or `Duration.zero`) to log all reads.
   - Use a higher threshold in normal runs to focus only on outliers.

---

## Testing guarantees

There are tests under `test/infrastructure/sqlite` that verify:

- Enabling storage logging on `MigrationRunner` does **not** prevent migrations from succeeding.
- Enabling storage logging on `SqliteSummaryRepository` (with a custom logger and `slowReadThreshold: Duration.zero`) preserves repository behavior and records both write and read events.

These tests ensure that the logging layer is safe to enable and does not change storage semantics.

