import 'package:personal_archive/src/application/search_index_sync.dart';
import 'package:personal_archive/infrastructure/sqlite/documents_fts_sync.dart';
import 'package:personal_archive/infrastructure/sqlite/migrations/migration_runner.dart'
    show MigrationDb;

/// SQLite implementation of [SearchIndexSync].
class SqliteFtsSyncService implements SearchIndexSync {
  const SqliteFtsSyncService(this._db);

  final MigrationDb _db;

  @override
  Future<void> syncDocument(String documentId) async {
    await syncFtsForDocument(_db, documentId);
  }
}
