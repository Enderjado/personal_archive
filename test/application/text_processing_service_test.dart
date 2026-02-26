import 'package:flutter_test/flutter_test.dart';
import 'package:personal_archive/src/application/text_processing_service_impl.dart';
import 'package:personal_archive/src/application/text_processing_errors.dart';
import 'package:personal_archive/src/domain/page.dart';
import 'package:personal_archive/src/domain/page_repository.dart';
import 'package:personal_archive/src/domain/text_processor.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

/// In-memory [PageRepository] that records every [update] call.
class _FakePageRepository implements PageRepository {
  _FakePageRepository(List<Page> pages) : _store = {for (final p in pages) p.id: p};

  final Map<String, Page> _store;
  final List<Page> updatedPages = [];

  @override
  Future<List<Page>> findByDocumentId(String documentId) async =>
      _store.values.where((p) => p.documentId == documentId).toList()
        ..sort((a, b) => a.pageNumber.compareTo(b.pageNumber));

  @override
  Future<void> update(Page page) async {
    _store[page.id] = page;
    updatedPages.add(page);
  }

  @override
  Future<void> insertAll(List<Page> pages) async {
    for (final p in pages) {
      _store[p.id] = p;
    }
  }
}

/// [TextProcessor] that prefixes cleaned text with 'cleaned:' for easy
/// assertion without pulling in the real OCR processing logic.
class _PrefixTextProcessor implements TextProcessor {
  const _PrefixTextProcessor();

  @override
  String clean(String raw) => 'cleaned:$raw';
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Page _page({
  required String id,
  required String documentId,
  required int pageNumber,
  String? rawText,
  String? processedText,
}) =>
    Page(
      id: id,
      documentId: documentId,
      pageNumber: pageNumber,
      rawText: rawText,
      processedText: processedText,
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  const processor = _PrefixTextProcessor();
  const docId = 'doc-1';

  group('TextProcessingServiceImpl – happy path', () {
    test('populates processedText for all pages with rawText', () async {
      final pages = [
        _page(id: 'p1', documentId: docId, pageNumber: 1, rawText: 'raw one'),
        _page(id: 'p2', documentId: docId, pageNumber: 2, rawText: 'raw two'),
        _page(id: 'p3', documentId: docId, pageNumber: 3, rawText: 'raw three'),
      ];
      final repo = _FakePageRepository(pages);
      final service = TextProcessingServiceImpl(
        pageRepository: repo,
        textProcessor: processor,
      );

      await service.processDocument(docId);

      final updated = await repo.findByDocumentId(docId);
      expect(updated[0].processedText, 'cleaned:raw one');
      expect(updated[1].processedText, 'cleaned:raw two');
      expect(updated[2].processedText, 'cleaned:raw three');
    });

    test('calls update once per page', () async {
      final pages = [
        _page(id: 'p1', documentId: docId, pageNumber: 1, rawText: 'a'),
        _page(id: 'p2', documentId: docId, pageNumber: 2, rawText: 'b'),
      ];
      final repo = _FakePageRepository(pages);
      final service = TextProcessingServiceImpl(
        pageRepository: repo,
        textProcessor: processor,
      );

      await service.processDocument(docId);

      expect(repo.updatedPages, hasLength(2));
    });

    test('throws DocumentHasNoPagesError for a document with no pages', () async {
      final repo = _FakePageRepository([]);
      final service = TextProcessingServiceImpl(
        pageRepository: repo,
        textProcessor: processor,
      );

      await expectLater(
        () => service.processDocument(docId),
        throwsA(isA<DocumentHasNoPagesError>()),
      );
    });

    test('skips pages whose rawText is null', () async {
      final pages = [
        _page(id: 'p1', documentId: docId, pageNumber: 1, rawText: 'text'),
        _page(id: 'p2', documentId: docId, pageNumber: 2, rawText: null),
      ];
      final repo = _FakePageRepository(pages);
      final service = TextProcessingServiceImpl(
        pageRepository: repo,
        textProcessor: processor,
      );

      await service.processDocument(docId);

      final updated = await repo.findByDocumentId(docId);
      expect(updated[0].processedText, 'cleaned:text');
      expect(updated[1].processedText, isNull);
      // Only one update should have been issued – for the page with rawText.
      expect(repo.updatedPages, hasLength(1));
    });
  });

  group('TextProcessingServiceImpl – idempotency', () {
    test('processedText is unchanged after a second run', () async {
      final pages = [
        _page(id: 'p1', documentId: docId, pageNumber: 1, rawText: 'raw one'),
        _page(id: 'p2', documentId: docId, pageNumber: 2, rawText: 'raw two'),
      ];
      final repo = _FakePageRepository(pages);
      final service = TextProcessingServiceImpl(
        pageRepository: repo,
        textProcessor: processor,
      );

      await service.processDocument(docId);
      final afterFirst = (await repo.findByDocumentId(docId))
          .map((p) => p.processedText)
          .toList();

      await service.processDocument(docId);
      final afterSecond = (await repo.findByDocumentId(docId))
          .map((p) => p.processedText)
          .toList();

      expect(afterSecond, equals(afterFirst));
    });

    test('does not call update for already-processed pages on second run',
        () async {
      final pages = [
        _page(id: 'p1', documentId: docId, pageNumber: 1, rawText: 'raw one'),
        _page(id: 'p2', documentId: docId, pageNumber: 2, rawText: 'raw two'),
      ];
      final repo = _FakePageRepository(pages);
      final service = TextProcessingServiceImpl(
        pageRepository: repo,
        textProcessor: processor,
      );

      await service.processDocument(docId);
      final updatesAfterFirst = repo.updatedPages.length;

      await service.processDocument(docId);
      final updatesAfterSecond = repo.updatedPages.length;

      // No additional updates should have been issued on the second run.
      expect(updatesAfterSecond, equals(updatesAfterFirst));
    });
  });
}
