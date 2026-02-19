import 'package:personal_archive/infrastructure/sqlite/migrations/migration_runner.dart'
    show MigrationDb;
import 'package:personal_archive/infrastructure/sqlite/storage_logging.dart';
import 'package:personal_archive/src/domain/domain.dart';

/// SQLite-backed implementation of [SummaryRepository].
///
/// Stores [Summary.createdAt] as Unix epoch milliseconds (INTEGER) in UTC.
class SqliteSummaryRepository implements SummaryRepository {
  SqliteSummaryRepository(
    this._db, {
    StorageLogger logger = const NoOpStorageLogger(),
  }) : _logger = logger;

  final MigrationDb _db;
  final StorageLogger _logger;

  static int _toEpochMillis(DateTime dateTime) {
    return dateTime.toUtc().millisecondsSinceEpoch;
  }

  static Summary _rowToSummary(Map<String, Object?> row) {
    final createdMillis = row['created_at'] as int;
    return Summary(
      documentId: row['document_id'] as String,
      text: row['text'] as String,
      modelVersion: row['model_version'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        createdMillis,
        isUtc: true,
      ),
    );
  }

  static Never _handleError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('foreign key') ||
        msg.contains('constraint') ||
        msg.contains('sqlite_constraint')) {
      throw StorageConstraintError(detail: e.toString());
    }
    throw StorageUnknownError(e);
  }

  @override
  Future<void> upsert(Summary summary) async {
    try {
      await timeWriteOperation<void>(
        logger: _logger,
        operation: 'upsert_summary',
        table: 'summaries',
        recordCount: 1,
        action: () => _db.execute(
          '''
          INSERT OR REPLACE INTO summaries (
            document_id,
            text,
            model_version,
            created_at
          ) VALUES (?, ?, ?, ?)
          ''',
          [
            summary.documentId,
            summary.text,
            summary.modelVersion,
            _toEpochMillis(summary.createdAt),
          ],
        ),
      );
    } catch (e) {
      _handleError(e);
    }
  }

  @override
  Future<Summary?> findByDocumentId(String documentId) async {
    try {
      final rows = await _db.query(
        'SELECT * FROM summaries WHERE document_id = ?',
        [documentId],
      );
      if (rows.isEmpty) return null;
      return _rowToSummary(rows.single);
    } catch (e) {
      _handleError(e);
    }
  }
}
