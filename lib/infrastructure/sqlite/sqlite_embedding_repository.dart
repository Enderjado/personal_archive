import 'dart:convert';

import 'package:personal_archive/infrastructure/sqlite/migrations/migration_runner.dart'
    show MigrationDb;
import 'package:personal_archive/infrastructure/sqlite/storage_logging.dart';
import 'package:personal_archive/src/domain/domain.dart';

/// SQLite-backed implementation of [EmbeddingRepository].
///
/// Stores [Embedding.vector] as TEXT containing a JSON array of doubles.
/// Stores [Embedding.createdAt] as Unix epoch milliseconds (INTEGER) in UTC
/// when present; otherwise NULL.
class SqliteEmbeddingRepository implements EmbeddingRepository {
  SqliteEmbeddingRepository(
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

  static DateTime? _fromEpochMillis(Object? value) {
    if (value == null) return null;
    final millis = value as int;
    return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
  }

  static String _vectorToJson(List<double> vector) {
    return jsonEncode(vector);
  }

  static List<double> _jsonToVector(String json) {
    final decoded = jsonDecode(json) as List<dynamic>;
    return decoded.map((e) => (e as num).toDouble()).toList();
  }

  static Embedding _rowToEmbedding(Map<String, Object?> row) {
    final createdAt = _fromEpochMillis(row['created_at']);
    final vectorJson = row['vector'] as String;
    return Embedding(
      documentId: row['document_id'] as String,
      vector: _jsonToVector(vectorJson),
      modelVersion: row['model_version'] as String?,
      createdAt: createdAt,
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
  Future<void> upsert(Embedding embedding) async {
    try {
      await timeWriteOperation<void>(
        logger: _logger,
        operation: 'upsert_embedding',
        table: 'embeddings',
        recordCount: 1,
        action: () => _db.execute(
          '''
          INSERT OR REPLACE INTO embeddings (
            document_id,
            vector,
            model_version,
            created_at
          ) VALUES (?, ?, ?, ?)
          ''',
          [
            embedding.documentId,
            _vectorToJson(embedding.vector),
            embedding.modelVersion,
            embedding.createdAt != null
                ? _toEpochMillis(embedding.createdAt!)
                : null,
          ],
        ),
      );
    } catch (e) {
      _handleError(e);
    }
  }

  @override
  Future<Embedding?> findByDocumentId(String documentId) async {
    try {
      final rows = await timeReadOperation<List<Map<String, Object?>>>(
        logger: _logger,
        operation: 'find_embedding_by_document_id',
        table: 'embeddings',
        slowLogThreshold: _slowReadThreshold,
        action: () => _db.query(
          'SELECT * FROM embeddings WHERE document_id = ?',
          [documentId],
        ),
      );
      if (rows.isEmpty) return null;
      return _rowToEmbedding(rows.single);
    } catch (e) {
      _handleError(e);
    }
  }
}

