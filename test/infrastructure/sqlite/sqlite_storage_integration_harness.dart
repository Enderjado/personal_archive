import 'package:personal_archive/infrastructure/sqlite/migrations/migration_runner.dart'
    show MigrationDb;
import 'package:personal_archive/infrastructure/sqlite/sqlite_document_keyword_repository.dart';
import 'package:personal_archive/infrastructure/sqlite/sqlite_document_repository.dart';
import 'package:personal_archive/infrastructure/sqlite/sqlite_embedding_repository.dart';
import 'package:personal_archive/infrastructure/sqlite/sqlite_keyword_repository.dart';
import 'package:personal_archive/infrastructure/sqlite/sqlite_page_repository.dart';
import 'package:personal_archive/infrastructure/sqlite/sqlite_place_repository.dart';
import 'package:personal_archive/infrastructure/sqlite/sqlite_summary_repository.dart';

import 'sqlite_test_harness.dart';

/// Aggregates a migrated SQLite database and all storage-layer repositories
/// used in end-to-end integration tests.
class StorageIntegrationContext {
  StorageIntegrationContext({
    required this.db,
    required this.documentRepository,
    required this.placeRepository,
    required this.pageRepository,
    required this.summaryRepository,
    required this.keywordRepository,
    required this.documentKeywordRepository,
    required this.embeddingRepository,
  });

  final MigrationDb db;
  final SqliteDocumentRepository documentRepository;
  final SqlitePlaceRepository placeRepository;
  final SqlitePageRepository pageRepository;
  final SqliteSummaryRepository summaryRepository;
  final SqliteKeywordRepository keywordRepository;
  final SqliteDocumentKeywordRepository documentKeywordRepository;
  final SqliteEmbeddingRepository embeddingRepository;
}

/// Creates a fresh in-memory SQLite database, runs all migrations, and
/// constructs repository instances wired to that database for use in
/// storage-layer end-to-end integration tests.
Future<StorageIntegrationContext> createStorageIntegrationContext() async {
  final db = await createMigratedTestDb();

  return StorageIntegrationContext(
    db: db,
    documentRepository: SqliteDocumentRepository(db),
    placeRepository: SqlitePlaceRepository(db),
    pageRepository: SqlitePageRepository(db),
    summaryRepository: SqliteSummaryRepository(db),
    keywordRepository: SqliteKeywordRepository(db),
    documentKeywordRepository: SqliteDocumentKeywordRepository(db),
    embeddingRepository: SqliteEmbeddingRepository(db),
  );
}

