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

  group('SqliteKeywordRepository', () {
    late MigrationDb db;
    late SqliteKeywordRepository repo;

    setUp(() async {
      final rawDb = sqlite.sqlite3.openInMemory();
      db = Sqlite3MigrationDb(rawDb);
      final runner = MigrationRunner(
        db: db,
        loadMigrations: _loadTestMigrations,
      );
      await runner.runAll();
      repo = SqliteKeywordRepository(db);
    });

    test('getOrCreate returns new keyword with correct value, type, globalFrequency 0',
        () async {
      final keyword = await repo.getOrCreate('bank', 'topic');
      expect(keyword.value, 'bank');
      expect(keyword.type, 'topic');
      expect(keyword.globalFrequency, 0);
      expect(keyword.id, isNotEmpty);
      expect(keyword.createdAt, isNotNull);
    });

    test('getOrCreate with same value and type returns same keyword (reuse)', () async {
      final k1 = await repo.getOrCreate('invoice', 'type');
      final k2 = await repo.getOrCreate('invoice', 'type');
      expect(k2.id, k1.id);
      expect(k2.value, k1.value);
      expect(k2.type, k1.type);
    });

    test('incrementGlobalFrequency increases globalFrequency', () async {
      final k1 = await repo.getOrCreate('transaction', 'topic');
      expect(k1.globalFrequency, 0);

      await repo.incrementGlobalFrequency(k1.id);

      final k2 = await repo.getOrCreate('transaction', 'topic');
      expect(k2.id, k1.id);
      expect(k2.globalFrequency, 1);
    });
  });

  group('SqliteDocumentKeywordRepository', () {
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
      await db.execute(
        '''
        INSERT INTO documents (
          id, title, file_path, status, confidence_score,
          place_id, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        [
          documentId,
          'Test Doc',
          '/path/to/doc.pdf',
          DocumentStatus.imported.name,
          null,
          null,
          0,
          0,
        ],
      );
    }

    test('upsertForDocument then listForDocument returns linked keywords', () async {
      const documentId = 'doc-with-keywords';
      await insertDocument(documentId);

      final k1 = await keywordRepo.getOrCreate('bank', 'topic');
      final k2 = await keywordRepo.getOrCreate('invoice', 'type');
      final relations = [
        DocumentKeywordRelation(
          id: 'rel-1',
          documentId: documentId,
          keywordId: k1.id,
          weight: 0.9,
          confidence: 0.95,
          source: 'llm',
        ),
        DocumentKeywordRelation(
          id: 'rel-2',
          documentId: documentId,
          keywordId: k2.id,
          weight: 0.7,
          confidence: 0.8,
        ),
      ];
      await docKeywordRepo.upsertForDocument(documentId, relations);

      final keywords = await docKeywordRepo.listForDocument(documentId);
      expect(keywords.length, 2);
      final ids = keywords.map((k) => k.id).toSet();
      expect(ids, contains(k1.id));
      expect(ids, contains(k2.id));
      final values = keywords.map((k) => k.value).toSet();
      expect(values, contains('bank'));
      expect(values, contains('invoice'));
    });

    test('second upsertForDocument replaces relations (no stale relations)', () async {
      const documentId = 'doc-replace-keywords';
      await insertDocument(documentId);

      final k1 = await keywordRepo.getOrCreate('old', 'topic');
      await docKeywordRepo.upsertForDocument(
        documentId,
        [
          DocumentKeywordRelation(
            id: 'rel-old',
            documentId: documentId,
            keywordId: k1.id,
            weight: 0.5,
            confidence: 0.5,
          ),
        ],
      );

      final k2 = await keywordRepo.getOrCreate('new', 'topic');
      await docKeywordRepo.upsertForDocument(
        documentId,
        [
          DocumentKeywordRelation(
            id: 'rel-new',
            documentId: documentId,
            keywordId: k2.id,
            weight: 0.8,
            confidence: 0.9,
          ),
        ],
      );

      final keywords = await docKeywordRepo.listForDocument(documentId);
      expect(keywords.length, 1);
      expect(keywords.single.id, k2.id);
      expect(keywords.single.value, 'new');
    });
  });
}
