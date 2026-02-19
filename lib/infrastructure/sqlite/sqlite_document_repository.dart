import 'package:personal_archive/infrastructure/sqlite/migrations/migration_runner.dart' show MigrationDb;
import 'package:personal_archive/src/domain/domain.dart';

/// SQLite-backed implementation of [DocumentRepository].
///
/// Uses [MigrationDb] for execution; stores dates as Unix seconds (INTEGER).
class SqliteDocumentRepository implements DocumentRepository {
  SqliteDocumentRepository(this._db);

  final MigrationDb _db;

  static int _toUnixSeconds(DateTime dateTime) {
    return dateTime.toUtc().millisecondsSinceEpoch ~/ 1000;
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
    final createdSecs = row['created_at'] as int? ?? 0;
    final updatedSecs = row['updated_at'] as int? ?? 0;
    return Document(
      id: id,
      title: title,
      filePath: filePath,
      status: status,
      confidenceScore: confidenceScore,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdSecs * 1000, isUtc: true),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedSecs * 1000, isUtc: true),
      placeId: placeId?.isEmpty == true ? null : placeId,
    );
  }

  @override
  Future<Document?> create(Document draft) async {
    try {
      await _db.execute(
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
          _toUnixSeconds(draft.createdAt),
          _toUnixSeconds(draft.updatedAt),
        ],
      );
      return draft;
    } catch (e) {
      throw StorageUnknownError(e);
    }
  }

  @override
  Future<Document?> findById(String id) async {
    try {
      final rows = await _db.query(
        'SELECT * FROM documents WHERE id = ?',
        [id],
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
      await _db.execute(
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
          _toUnixSeconds(document.updatedAt),
          document.id,
        ],
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
        params.add(_toUnixSeconds(createdBetween.start));
        conditions.add('created_at <= ?');
        params.add(_toUnixSeconds(createdBetween.end));
      }
      final whereClause = conditions.isEmpty
          ? ''
          : 'WHERE ${conditions.join(' AND ')}';
      final rows = await _db.query(
        'SELECT * FROM documents $whereClause ORDER BY created_at DESC',
        params,
      );
      return rows.map(_rowToDocument).toList();
    } catch (e) {
      throw StorageUnknownError(e);
    }
  }
}
