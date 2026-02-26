import 'package:flutter_test/flutter_test.dart';
import 'package:personal_archive/src/application/application.dart';
import 'package:personal_archive/src/domain/domain.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _docId = 'doc-001';

/// Builds a string of [wordCount] distinct words separated by single spaces.
String _words(int wordCount, {String prefix = 'word'}) =>
    List.generate(wordCount, (i) => '${prefix}_$i').join(' ');

/// Estimates tokens the same way ParagraphChunker does (wordCount × 1.3, ceil).
int _est(String text) {
  final wordCount =
      text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
  return (wordCount * 1.3).ceil();
}

void main() {
  group('ParagraphChunker – boundary conditions', () {
    // -------------------------------------------------------------------------
    // Empty input
    // -------------------------------------------------------------------------

    group('empty input', () {
      const chunker = ParagraphChunker();

      test('returns empty list for empty string', () {
        expect(chunker.chunk('', documentId: _docId), isEmpty);
      });

      test('returns empty list for whitespace-only string', () {
        expect(chunker.chunk('   \n\n  ', documentId: _docId), isEmpty);
      });
    });

    // -------------------------------------------------------------------------
    // Single-chunk documents
    // -------------------------------------------------------------------------

    group('single-chunk documents', () {
      const chunker = ParagraphChunker();

      test('single character produces one chunk', () {
        final chunks = chunker.chunk('A', documentId: _docId);
        expect(chunks, hasLength(1));
        expect(chunks.first.text, 'A');
      });

      test('chunk carries the supplied documentId', () {
        final chunks = chunker.chunk('Hello world.', documentId: _docId);
        expect(chunks.first.documentId, _docId);
      });

      test('chunk carries supplied pageNumber', () {
        final chunks =
            chunker.chunk('Hello.', documentId: _docId, pageNumber: 3);
        expect(chunks.first.pageNumber, 3);
      });

      test('chunk has null pageNumber when none supplied', () {
        final chunks = chunker.chunk('Hello.', documentId: _docId);
        expect(chunks.first.pageNumber, isNull);
      });

      test('chunk has positive tokenCount', () {
        final chunks = chunker.chunk('Hello world.', documentId: _docId);
        expect(chunks.first.tokenCount, greaterThan(0));
      });

      test('two small paragraphs are merged into one chunk', () {
        const text = 'First paragraph.\n\nSecond paragraph.';
        final chunks = chunker.chunk(text, documentId: _docId);
        expect(chunks, hasLength(1));
      });

      test('document that fits within budget produces exactly one chunk', () {
        // Use small config so the test text is manageable.
        const chunker = ParagraphChunker(
          config: ChunkingConfig(
            maxTokensPerChunk: 50,
            minTokensPerChunk: 5,
            overlapFraction: 0,
          ),
        );
        // ~15 words → ~20 tokens, well under budget of 50.
        const text =
            'The quick brown fox jumps over the lazy dog.\n\nA second short paragraph.';
        final chunks = chunker.chunk(text, documentId: _docId);
        expect(chunks, hasLength(1));
      });
    });

    // -------------------------------------------------------------------------
    // Multi-chunk splitting
    // -------------------------------------------------------------------------

    group('multi-chunk splitting', () {
      test('over-budget input produces multiple chunks', () {
        // Budget: 10 tokens.  Each paragraph ≈ 8 words = 11 tokens → over.
        const config = ChunkingConfig(
          maxTokensPerChunk: 10,
          minTokensPerChunk: 1,
          overlapFraction: 0,
        );
        const chunker = ParagraphChunker(config: config);

        final para1 = _words(8, prefix: 'alpha');
        final para2 = _words(8, prefix: 'beta');
        final text = '$para1\n\n$para2';

        final chunks = chunker.chunk(text, documentId: _docId);
        expect(chunks.length, greaterThanOrEqualTo(2));
      });

      test('every chunk has non-empty text', () {
        const config = ChunkingConfig(
          maxTokensPerChunk: 10,
          minTokensPerChunk: 1,
          overlapFraction: 0,
        );
        const chunker = ParagraphChunker(config: config);

        final text = List.generate(5, (i) => _words(8, prefix: 'p$i')).join('\n\n');
        final chunks = chunker.chunk(text, documentId: _docId);

        for (final chunk in chunks) {
          expect(chunk.text.trim(), isNotEmpty);
        }
      });

      test('every chunk has positive tokenCount', () {
        const config = ChunkingConfig(
          maxTokensPerChunk: 10,
          minTokensPerChunk: 1,
          overlapFraction: 0,
        );
        const chunker = ParagraphChunker(config: config);

        final text = List.generate(5, (i) => _words(8, prefix: 'p$i')).join('\n\n');
        final chunks = chunker.chunk(text, documentId: _docId);

        for (final chunk in chunks) {
          expect(chunk.tokenCount, greaterThan(0));
        }
      });

      test('tokenCount of each chunk does not greatly exceed the budget', () {
        const maxTokens = 20;
        const config = ChunkingConfig(
          maxTokensPerChunk: maxTokens,
          minTokensPerChunk: 1,
          overlapFraction: 0,
        );
        const chunker = ParagraphChunker(config: config);

        // Build paragraphs that are each just under budget.
        final text =
            List.generate(6, (i) => _words(12, prefix: 'p$i')).join('\n\n');
        final chunks = chunker.chunk(text, documentId: _docId);

        for (final chunk in chunks) {
          // Allow up to 2× for overlap; overlap is disabled here, so any
          // single-unit chunk should be close to budget.
          expect(
            chunk.tokenCount,
            lessThanOrEqualTo(maxTokens * 2),
            reason: 'chunk "${chunk.text.substring(0, 20)}…" exceeds 2× budget',
          );
        }
      });

      test('all chunks together cover all content words without overlap', () {
        const config = ChunkingConfig(
          maxTokensPerChunk: 10,
          minTokensPerChunk: 1,
          overlapFraction: 0, // no overlap so every word appears exactly once
        );
        const chunker = ParagraphChunker(config: config);

        final paragraphs =
            List.generate(4, (i) => _words(8, prefix: 'p$i'));
        final text = paragraphs.join('\n\n');
        final chunks = chunker.chunk(text, documentId: _docId);

        final allWords =
            chunks.map((c) => c.text).join(' ').split(RegExp(r'\s+')).toSet();

        for (final para in paragraphs) {
          for (final word in para.split(' ')) {
            expect(allWords, contains(word));
          }
        }
      });
    });

    // -------------------------------------------------------------------------
    // Over-budget single paragraph / sentence
    // -------------------------------------------------------------------------

    group('over-budget single paragraph', () {
      test('single over-budget paragraph is split into multiple chunks', () {
        const config = ChunkingConfig(
          maxTokensPerChunk: 10,
          minTokensPerChunk: 1,
          overlapFraction: 0,
        );
        const chunker = ParagraphChunker(config: config);

        // 40 words in one paragraph → no double-newline → falls through to
        // sentence / word-window splitting.
        final text = _words(40);
        final chunks = chunker.chunk(text, documentId: _docId);
        expect(chunks.length, greaterThan(1));
      });
    });

    // -------------------------------------------------------------------------
    // Tiny trailing fragment
    // -------------------------------------------------------------------------

    group('tiny trailing fragment', () {
      test('short trailing fragment is merged into previous chunk', () {
        // Budget: 20 tokens.  Three paragraphs: two at ~15 tokens, one at 2 tokens.
        // The tiny last paragraph should be merged into the second chunk.
        const config = ChunkingConfig(
          maxTokensPerChunk: 20,
          minTokensPerChunk: 5, // fragments below 5 tokens get merged
          overlapFraction: 0,
        );
        const chunker = ParagraphChunker(config: config);

        final para1 = _words(11, prefix: 'a'); // ~15 tokens
        final para2 = _words(11, prefix: 'b'); // ~15 tokens
        const tiny = 'end'; // 2 tokens

        final text = '$para1\n\n$para2\n\n$tiny';
        final chunks = chunker.chunk(text, documentId: _docId);

        // The word "end" must appear somewhere in the chunks.
        final allText = chunks.map((c) => c.text).join(' ');
        expect(allText, contains('end'));

        // And it should NOT be its own isolated chunk.
        final singleWordChunks =
            chunks.where((c) => c.text.trim() == 'end').toList();
        expect(singleWordChunks, isEmpty);
      });
    });

    // -------------------------------------------------------------------------
    // Overlap
    // -------------------------------------------------------------------------

    group('overlap', () {
      test('second chunk starts with words from end of first chunk', () {
        const config = ChunkingConfig(
          maxTokensPerChunk: 10,
          minTokensPerChunk: 1,
          overlapFraction: 0.2, // 20% of 10 = 2 tokens ≈ 1 word overlap
        );
        const chunker = ParagraphChunker(config: config);

        // 7 words → exactly 10 tokens = budget; each paragraph is one unit.
        final para1 = _words(7, prefix: 'a');
        final para2 = _words(7, prefix: 'b');
        final text = '$para1\n\n$para2';

        final chunks = chunker.chunk(text, documentId: _docId);
        expect(chunks.length, greaterThanOrEqualTo(2));

        // The last word of chunk 0 should appear in chunk 1.
        final lastWordChunk0 = chunks[0].text.trim().split(' ').last;
        expect(chunks[1].text, contains(lastWordChunk0));
      });

      test('no overlap when overlapFraction is zero', () {
        const config = ChunkingConfig(
          maxTokensPerChunk: 10,
          minTokensPerChunk: 1,
          overlapFraction: 0,
        );
        const chunker = ParagraphChunker(config: config);

        // 7 words → ceil(7 * 1.3) = 10 tokens = exactly the budget.
        // Each paragraph fits as one atomic unit, so word-window splitting is
        // not triggered and each paragraph maps cleanly to its own chunk.
        final para1 = _words(7, prefix: 'alpha');
        final para2 = _words(7, prefix: 'beta');
        final text = '$para1\n\n$para2';

        final chunks = chunker.chunk(text, documentId: _docId);
        expect(chunks.length, greaterThanOrEqualTo(2));

        // No word from para1 should appear in the chunk that holds para2.
        final para1Words = para1.split(' ').toSet();
        final lastChunkWords =
            chunks.last.text.split(RegExp(r'\s+')).toSet();
        expect(lastChunkWords.intersection(para1Words), isEmpty);
      });
    });
  });
}
