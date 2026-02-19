import 'dart:math';

import 'package:personal_archive/infrastructure/sqlite/migrations/migration_runner.dart'
    show MigrationDb;
import 'package:personal_archive/infrastructure/sqlite/storage_logging.dart';
import 'package:personal_archive/src/domain/domain.dart';

/// SQLite-backed implementation of [PlaceRepository].
///
/// Name normalization: leading and trailing whitespace is trimmed before lookup
/// and insert. Names are case-sensitive (no lowercasing), matching SQLite's
/// default UNIQUE semantics.
///
/// Stores [Place.createdAt] and [Place.updatedAt] as Unix epoch milliseconds
/// (INTEGER) in UTC.
class SqlitePlaceRepository implements PlaceRepository {
  SqlitePlaceRepository(
    this._db, {
    StorageLogger logger = const NoOpStorageLogger(),
  }) : _logger = logger;

  final MigrationDb _db;
  final StorageLogger _logger;
  static final Random _random = Random();

  /// Trim leading/trailing whitespace; names remain case-sensitive.
  static String _normalizeName(String name) => name.trim();

  static int _toEpochMillis(DateTime dateTime) {
    return dateTime.toUtc().millisecondsSinceEpoch;
  }

  static Place _rowToPlace(Map<String, Object?> row) {
    final createdMillis = row['created_at'] as int;
    final updatedMillis = row['updated_at'] as int;
    final desc = row['description'];
    return Place(
      id: row['id'] as String,
      name: row['name'] as String,
      description: desc != null ? desc as String : null,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdMillis, isUtc: true),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedMillis, isUtc: true),
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
  Future<Place> getOrCreate(String name) async {
    try {
      final normalized = _normalizeName(name);
      final rows = await _db.query(
        'SELECT * FROM places WHERE name = ?',
        [normalized],
      );
      if (rows.isNotEmpty) return _rowToPlace(rows.single);

      final id = _generateId();
      final now = DateTime.now().toUtc();
      final ts = _toEpochMillis(now);
      await timeWriteOperation<void>(
        logger: _logger,
        operation: 'get_or_create_place_insert',
        table: 'places',
        recordCount: 1,
        action: () => _db.execute(
          '''
          INSERT INTO places (id, name, description, created_at, updated_at)
          VALUES (?, ?, NULL, ?, ?)
          ''',
          [id, normalized, ts, ts],
        ),
      );
      return Place(
        id: id,
        name: normalized,
        description: null,
        createdAt: now,
        updatedAt: now,
      );
    } catch (e) {
      _handleError(e);
    }
  }

  @override
  Future<List<Place>> listAll() async {
    try {
      final rows = await _db.query(
        'SELECT * FROM places ORDER BY name',
        [],
      );
      return rows.map(_rowToPlace).toList();
    } catch (e) {
      _handleError(e);
    }
  }
}
