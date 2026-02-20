import 'package:personal_archive/infrastructure/sqlite/migrations/migration_runner.dart'
    show MigrationDb;
import 'package:personal_archive/infrastructure/sqlite/storage_logging.dart';
import 'package:personal_archive/src/domain/domain.dart';

/// SQLite-backed implementation of [DocumentRepository].
///
/// Uses [MigrationDb] for execution; stores dates as Unix epoch
/// milliseconds (INTEGER) in UTC.
class SqliteDocumentRepository implements DocumentRepository {
  SqliteDocumentRepository(
    this._db, {
    StorageLogger logger = const NoOpStorageLogger(),
    Duration slowReadThreshold = const Duration(milliseconds: 75),
  })  : _logger = logger,
        _slowReadThreshold = slowReadThreshold;

  final MigrationDb _db;
  final StorageLogger _logger;
  final Duration _slowReadThreshold;

  static int _toEpochMillis(DateTime dateTime) {
    return dateTime.toUtc().millisecondsSinceEpoch;
  }

  static DocumentStatus _statusFromString(String value) {
    return DocumentStatus.values.byName(value);
  }

  static Document _rowToDocument(Map<String, Object?> row) {
    final id = row['id'] as String;
    final title = row['title'] as String;
    final filePath = row['file_path'] as String;
    final status = _statusFromString(row['status'] as String);
    final confidenceScore = row['confidence_score'] as double?;
    final placeId = row['place_id'] as String?;
    final createdMillis = row['created_at'] as int? ?? 0;
    final updatedMillis = row['updated_at'] as int? ?? 0;
    return Document(
      id: id,
      title: title,
      filePath: filePath,
      status: status,
      confidenceScore: confidenceScore,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        createdMillis,
        isUtc: true,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        updatedMillis,
        isUtc: true,
      ),
      placeId: placeId?.isEmpty == true ? null : placeId,
    );
  }

  @override
  Future<Document?> create(Document draft) async {
    try {
      await timeWriteOperation<void>(
        logger: _logger,
        operation: 'create_document',
        table: 'documents',
        recordCount: 1,
        action: () => _db.execute(
          '''
          INSERT INTO documents (
            id, title, file_path, status, confidence_score,
            place_id, created_at, updated_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
          ''',
          [
            draft.id,
            draft.title,
            draft.filePath,
            draft.status.name,
            draft.confidenceScore,
            draft.placeId,
            _toEpochMillis(draft.createdAt),
            _toEpochMillis(draft.updatedAt),
          ],
        ),
      );
      return draft;
    } catch (e) {
      throw StorageUnknownError(e);
    }
  }

  @override
  Future<Document?> findById(String id) async {
    try {
      final rows = await timeReadOperation<List<Map<String, Object?>>>(
        logger: _logger,
        operation: 'find_document_by_id',
        table: 'documents',
        slowLogThreshold: _slowReadThreshold,
        action: () => _db.query(
          'SELECT * FROM documents WHERE id = ?',
          [id],
        ),
      );
      if (rows.isEmpty) return null;
      return _rowToDocument(rows.single);
    } catch (e) {
      throw StorageUnknownError(e);
    }
  }

  @override
  Future<Document?> update(Document document) async {
    try {
      await timeWriteOperation<void>(
        logger: _logger,
        operation: 'update_document',
        table: 'documents',
        recordCount: 1,
        action: () => _db.execute(
          '''
          UPDATE documents SET
            title = ?, file_path = ?, status = ?, confidence_score = ?,
            place_id = ?, updated_at = ?
          WHERE id = ?
          ''',
          [
            document.title,
            document.filePath,
            document.status.name,
            document.confidenceScore,
            document.placeId,
            _toEpochMillis(document.updatedAt),
            document.id,
          ],
        ),
      );
      return document;
    } catch (e) {
      throw StorageUnknownError(e);
    }
  }

  @override
  Future<List<Document>> list({
    DocumentStatus? status,
    String? placeId,
    DateTimeRange? createdBetween,
  }) async {
    try {
      final conditions = <String>[];
      final params = <Object?>[];
      if (status != null) {
        conditions.add('status = ?');
        params.add(status.name);
      }
      if (placeId != null) {
        conditions.add('place_id = ?');
        params.add(placeId);
      }
      if (createdBetween != null) {
        conditions.add('created_at >= ?');
        params.add(_toEpochMillis(createdBetween.start));
        conditions.add('created_at <= ?');
        params.add(_toEpochMillis(createdBetween.end));
      }
      final whereClause = conditions.isEmpty
          ? ''
          : 'WHERE ${conditions.join(' AND ')}';
      final rows = await timeReadOperation<List<Map<String, Object?>>>(
        logger: _logger,
        operation: 'list_documents',
        table: 'documents',
        slowLogThreshold: _slowReadThreshold,
        action: () => _db.query(
          'SELECT * FROM documents $whereClause ORDER BY created_at DESC',
          params,
        ),
      );
      return rows.map(_rowToDocument).toList();
    } catch (e) {
      throw StorageUnknownError(e);
    }
  }

  @override
  Future<void> delete(String id) async {
    try {
      await _db.execute('DELETE FROM documents WHERE id = ?', [id]);
    } catch (e) {
      throw StorageUnknownError(e);
    }
  }
}
