import 'package:personal_archive/infrastructure/sqlite/migrations/migration_runner.dart'
    show MigrationDb;
import 'package:personal_archive/infrastructure/sqlite/storage_logging.dart';
import 'package:personal_archive/src/domain/domain.dart';

/// SQLite-backed implementation of [PageRepository].
class SqlitePageRepository implements PageRepository {
  SqlitePageRepository(
    this._db, {
    StorageLogger logger = const NoOpStorageLogger(),
  }) : _logger = logger;

  final MigrationDb _db;
  final StorageLogger _logger;

  static Page _rowToPage(Map<String, Object?> row) {
    return Page(
      id: row['id'] as String,
      documentId: row['document_id'] as String,
      pageNumber: row['page_number'] as int,
      rawText: row['raw_text'] as String?,
      processedText: row['processed_text'] as String?,
      ocrConfidence: row['ocr_confidence'] as double?,
    );
  }

  @override
  Future<void> insertAll(List<Page> pages) {
    if (pages.isEmpty) {
      return Future.value();
    }

    return timeWriteOperation<void>(
      logger: _logger,
      operation: 'insert_pages_bulk',
      table: 'pages',
      recordCount: pages.length,
      action: () => _db.transaction(() async {
        for (final page in pages) {
          await _db.execute(
            '''
            INSERT INTO pages (
              id,
              document_id,
              page_number,
              raw_text,
              processed_text,
              ocr_confidence
            ) VALUES (?, ?, ?, ?, ?, ?)
            ''',
            [
              page.id,
              page.documentId,
              page.pageNumber,
              page.rawText,
              page.processedText,
              page.ocrConfidence,
            ],
          );
        }
      }),
    ).catchError((error, _) {
      throw StorageUnknownError(error);
    });
  }

  @override
  Future<List<Page>> findByDocumentId(String documentId) async {
    try {
      final rows = await _db.query(
        'SELECT * FROM pages WHERE document_id = ? ORDER BY page_number',
        [documentId],
      );
      if (rows.isEmpty) {
        return const [];
      }
      return rows.map(_rowToPage).toList();
    } catch (e) {
      throw StorageUnknownError(e);
    }
  }
}

