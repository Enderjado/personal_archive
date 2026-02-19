import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_archive/infrastructure/sqlite/migrations/migration.dart';
import 'package:personal_archive/infrastructure/sqlite/migrations/migration_runner.dart';
import 'package:personal_archive/infrastructure/sqlite/sqlite_document_keyword_repository.dart';
import 'package:personal_archive/infrastructure/sqlite/sqlite_keyword_repository.dart';
import 'package:personal_archive/src/domain/domain.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

class Sqlite3MigrationDb implements MigrationDb {
  Sqlite3MigrationDb(this._db) {
    _db.execute('PRAGMA foreign_keys = ON');
  }

  final sqlite.Database _db;

  @override
  Future<void> execute(String sql, [List<Object?> parameters = const []]) async {
    _db.execute(sql, parameters);
  }

  @override
  Future<List<Map<String, Object?>>> query(
    String sql, [
    List<Object?> parameters = const [],
  ]) async {
    final result = _db.select(sql, parameters);
    return result
        .map<Map<String, Object?>>((row) => Map<String, Object?>.from(row))
        .toList();
  }

  @override
  Future<T> transaction<T>(Future<T> Function() action) async {
    _db.execute('BEGIN');
    try {
      final result = await action();
      _db.execute('COMMIT');
      return result;
    } catch (e) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }
}

Future<List<Migration>> _loadTestMigrations() async {
  final initSql =
      await rootBundle.loadString('assets/sql/migrations/001_init_core_schema.sql');
  final placesSql =
      await rootBundle.loadString('assets/sql/migrations/002_add_places.sql');
  final documentsAndPagesSql = await rootBundle
      .loadString('assets/sql/migrations/003_add_documents_and_pages.sql');
  final summariesSql =
      await rootBundle.loadString('assets/sql/migrations/004_add_summaries.sql');
  final keywordsSql =
      await rootBundle.loadString('assets/sql/migrations/005_add_keywords.sql');
  final documentKeywordsSql = await rootBundle
      .loadString('assets/sql/migrations/006_add_document_keywords.sql');
  final embeddingsSql =
      await rootBundle.loadString('assets/sql/migrations/007_add_embeddings.sql');
  final documentsFtsSql =
      await rootBundle.loadString('assets/sql/migrations/008_add_documents_fts.sql');

  return <Migration>[
    Migration(name: '001_init_core_schema', sql: initSql),
    Migration(name: '002_add_places', sql: placesSql),
    Migration(name: '003_add_documents_and_pages', sql: documentsAndPagesSql),
    Migration(name: '004_add_summaries', sql: summariesSql),
    Migration(name: '005_add_keywords', sql: keywordsSql),
    Migration(name: '006_add_document_keywords', sql: documentKeywordsSql),
    Migration(name: '007_add_embeddings', sql: embeddingsSql),
    Migration(name: '008_add_documents_fts', sql: documentsFtsSql),
  ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Keyword and DocumentKeyword integration', () {
    late MigrationDb db;
    late SqliteKeywordRepository keywordRepo;
    late SqliteDocumentKeywordRepository docKeywordRepo;

    setUp(() async {
      final rawDb = sqlite.sqlite3.openInMemory();
      db = Sqlite3MigrationDb(rawDb);
      final runner = MigrationRunner(
        db: db,
        loadMigrations: _loadTestMigrations,
      );
      await runner.runAll();
      keywordRepo = SqliteKeywordRepository(db);
      docKeywordRepo = SqliteDocumentKeywordRepository(db);
    });

    Future<void> insertDocument(String documentId) async {
      final epoch = DateTime.utc(2025, 2, 19).millisecondsSinceEpoch;
      await db.execute(
        '''
        INSERT INTO documents (
          id, title, file_path, status, confidence_score,
          place_id, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        [
          documentId,
          'Integration Doc',
          '/path/integration.pdf',
          DocumentStatus.imported.name,
          null,
          null,
          epoch,
          epoch,
        ],
      );
    }

    test(
      'full migration + insert document + upsert relations + listForDocument returns keywords',
      () async {
        const documentId = 'doc-integration-cycle';
        await insertDocument(documentId);

        final k1 = await keywordRepo.getOrCreate('bank', 'topic');
        final k2 = await keywordRepo.getOrCreate('invoice', 'type');

        await docKeywordRepo.upsertForDocument(
          documentId,
          [
            DocumentKeywordRelation(
              id: 'rel-int-1',
              documentId: documentId,
              keywordId: k1.id,
              weight: 0.9,
              confidence: 0.95,
              source: 'llm',
            ),
            DocumentKeywordRelation(
              id: 'rel-int-2',
              documentId: documentId,
              keywordId: k2.id,
              weight: 0.7,
              confidence: 0.85,
            ),
          ],
        );

        final keywords = await docKeywordRepo.listForDocument(documentId);
        expect(keywords.length, 2);
        final ids = keywords.map((k) => k.id).toSet();
        expect(ids, containsAll(<String>[k1.id, k2.id]));
      },
    );

    test(
      'repeated getOrCreate and upsertForDocument do not create duplicate rows',
      () async {
        const documentId = 'doc-no-duplicates';
        await insertDocument(documentId);

        final k1 = await keywordRepo.getOrCreate('duplicate', 'topic');
        final k2 = await keywordRepo.getOrCreate('duplicate', 'topic');
        expect(k2.id, k1.id);

        final keywordRows = await db.query(
          '''
          SELECT COUNT(*) AS count
          FROM keywords
          WHERE value = ? AND type = ?
          ''',
          ['duplicate', 'topic'],
        );
        final keywordCount = keywordRows.single['count'] as int;
        expect(keywordCount, 1);

        final relations = [
          DocumentKeywordRelation(
            id: 'rel-dupe-1',
            documentId: documentId,
            keywordId: k1.id,
            weight: 0.5,
            confidence: 0.6,
          ),
        ];

        await docKeywordRepo.upsertForDocument(documentId, relations);
        await docKeywordRepo.upsertForDocument(documentId, relations);

        final relationRows = await db.query(
          '''
          SELECT COUNT(*) AS count
          FROM document_keywords
          WHERE document_id = ?
          ''',
          [documentId],
        );
        final relationCount = relationRows.single['count'] as int;
        expect(relationCount, relations.length);
      },
    );
  });
}

