import 'package:personal_archive/infrastructure/sqlite/migrations/migration_runner.dart'
    show MigrationDb;
import 'package:personal_archive/src/domain/domain.dart';

/// SQLite-backed implementation of [DocumentKeywordRepository].
///
/// [upsertForDocument] replaces all relations for a document (delete then insert).
class SqliteDocumentKeywordRepository implements DocumentKeywordRepository {
  SqliteDocumentKeywordRepository(this._db);

  final MigrationDb _db;

  static Keyword _rowToKeyword(Map<String, Object?> row) {
    final createdMillis = row['created_at'] as int;
    return Keyword(
      id: row['id'] as String,
      value: row['value'] as String,
      type: row['type'] as String,
      globalFrequency: row['global_frequency'] as int,
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
  Future<void> upsertForDocument(
    String documentId,
    List<DocumentKeywordRelation> relations,
  ) async {
    try {
      await _db.transaction(() async {
        await _db.execute(
          'DELETE FROM document_keywords WHERE document_id = ?',
          [documentId],
        );
        for (final r in relations) {
          await _db.execute(
            '''
            INSERT INTO document_keywords (
              id, document_id, keyword_id, weight, confidence, source
            ) VALUES (?, ?, ?, ?, ?, ?)
            ''',
            [
              r.id,
              r.documentId,
              r.keywordId,
              r.weight,
              r.confidence,
              r.source,
            ],
          );
        }
      });
    } catch (e) {
      _handleError(e);
    }
  }

  @override
  Future<List<Keyword>> listForDocument(String documentId) async {
    try {
      final rows = await _db.query(
        '''
        SELECT
          k.id AS id,
          k.value AS value,
          k.type AS type,
          k.global_frequency AS global_frequency,
          k.created_at AS created_at
        FROM document_keywords dk
        JOIN keywords k ON dk.keyword_id = k.id
        WHERE dk.document_id = ?
        ''',
        [documentId],
      );
      return rows.map(_rowToKeyword).toList();
    } catch (e) {
      _handleError(e);
    }
  }
}
