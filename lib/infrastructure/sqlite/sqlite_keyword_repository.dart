import 'dart:math';

import 'package:personal_archive/infrastructure/sqlite/migrations/migration_runner.dart'
    show MigrationDb;
import 'package:personal_archive/src/domain/domain.dart';

/// SQLite-backed implementation of [KeywordRepository].
///
/// Stores [Keyword.createdAt] as Unix epoch milliseconds (INTEGER) in UTC.
class SqliteKeywordRepository implements KeywordRepository {
  SqliteKeywordRepository(this._db);

  final MigrationDb _db;
  static final Random _random = Random();

  static int _toEpochMillis(DateTime dateTime) {
    return dateTime.toUtc().millisecondsSinceEpoch;
  }

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

  static String _generateId() {
    final micro = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final r = _random.nextInt(0x7FFFFFFF).toRadixString(36);
    return '$micro-$r';
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
  Future<Keyword> getOrCreate(String value, String type) async {
    try {
      final rows = await _db.query(
        'SELECT * FROM keywords WHERE value = ? AND type = ?',
        [value, type],
      );
      if (rows.isNotEmpty) return _rowToKeyword(rows.single);

      final id = _generateId();
      final now = DateTime.now().toUtc();
      await _db.execute(
        '''
        INSERT INTO keywords (id, value, type, global_frequency, created_at)
        VALUES (?, ?, ?, 0, ?)
        ''',
        [id, value, type, _toEpochMillis(now)],
      );
      return Keyword(
        id: id,
        value: value,
        type: type,
        globalFrequency: 0,
        createdAt: now,
      );
    } catch (e) {
      _handleError(e);
    }
  }

  @override
  Future<void> incrementGlobalFrequency(String keywordId) async {
    try {
      await _db.execute(
        'UPDATE keywords SET global_frequency = global_frequency + 1 WHERE id = ?',
        [keywordId],
      );
    } catch (e) {
      _handleError(e);
    }
  }
}
