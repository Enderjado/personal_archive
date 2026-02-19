import 'package:personal_archive/infrastructure/sqlite/migrations/migration_runner.dart' show MigrationDb;

/// Application-driven sync of [documents_fts] for a single document.
///
/// Reads title, page text, summary, and keywords for [documentId], builds
/// FTS content, and updates the `documents_fts` table (delete existing row
/// then insert). Aligns with docs/storage_conventions.md § 7.
Future<void> syncFtsForDocument(MigrationDb db, String documentId) async {
  final parts = <String>[];

  final docRows = await db.query(
    'SELECT title FROM documents WHERE id = ?',
    [documentId],
  );
  if (docRows.isEmpty) return;
  parts.add((docRows.single['title'] as String?) ?? '');

  final pageRows = await db.query(
    '''
    SELECT COALESCE(processed_text, raw_text, '') AS text
    FROM pages
    WHERE document_id = ?
    ORDER BY page_number
    ''',
    [documentId],
  );
  for (final row in pageRows) {
    final text = row['text'] as String?;
    if (text != null && text.isNotEmpty) parts.add(text);
  }

  final summaryRows = await db.query(
    'SELECT text FROM summaries WHERE document_id = ?',
    [documentId],
  );
  if (summaryRows.isNotEmpty) {
    final text = summaryRows.single['text'] as String?;
    if (text != null && text.isNotEmpty) parts.add(text);
  }

  final keywordRows = await db.query(
    '''
    SELECT k.value
    FROM document_keywords dk
    JOIN keywords k ON k.id = dk.keyword_id
    WHERE dk.document_id = ?
    ORDER BY k.value
    ''',
    [documentId],
  );
  for (final row in keywordRows) {
    final value = row['value'] as String?;
    if (value != null && value.isNotEmpty) parts.add(value);
  }

  final content = parts.join(' ');

  await db.execute(
    'DELETE FROM documents_fts WHERE document_id = ?',
    [documentId],
  );
  await db.execute(
    'INSERT INTO documents_fts(document_id, content) VALUES (?, ?)',
    [documentId, content],
  );
}
