import '../domain/chunker.dart';
import '../domain/chunking_config.dart';
import '../domain/text_chunk.dart';

/// A [Chunker] that splits cleaned text on semantic boundaries.
///
/// Splitting priority (ADR 0018):
/// 1. Paragraph breaks (double newlines).
/// 2. Sentence boundaries (when a paragraph exceeds the token budget).
/// 3. Word boundaries as a last resort for overlong sentences.
///
/// A configurable overlap (default 10 %) repeats the tail of each chunk at the
/// start of the next to preserve continuity across boundaries.
class ParagraphChunker implements Chunker {
  const ParagraphChunker({this.config = const ChunkingConfig()});

  final ChunkingConfig config;

  @override
  List<TextChunk> chunk(
    String cleaned, {
    required String documentId,
    int? pageNumber,
  }) {
    if (cleaned.trim().isEmpty) return [];

    // 1. Break into atomic units (paragraph → sentence → word-window).
    final units = _splitToUnits(cleaned);

    // 2. Greedily merge units into chunks within the token budget.
    final rawChunks = _mergeIntoChunks(units);

    // 3. Apply overlap between neighbouring chunks.
    final overlapped = _applyOverlap(rawChunks);

    // 4. Wrap in TextChunk value objects.
    return overlapped
        .map(
          (text) => TextChunk(
            documentId: documentId,
            text: text,
            tokenCount: _estimateTokens(text),
            pageNumber: pageNumber,
          ),
        )
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Step 1 – split to atomic units
  // ---------------------------------------------------------------------------

  /// Splits [text] into the smallest units that respect token budget.
  ///
  /// First splits on paragraph breaks, then sub-splits oversized paragraphs
  /// on sentence endings, then further by word window if needed.
  List<String> _splitToUnits(String text) {
    final paragraphs =
        text.split(RegExp(r'\n\n+')).map((p) => p.trim()).where((p) => p.isNotEmpty);

    final units = <String>[];
    for (final paragraph in paragraphs) {
      if (_estimateTokens(paragraph) <= config.maxTokensPerChunk) {
        units.add(paragraph);
      } else {
        units.addAll(_splitBySentences(paragraph));
      }
    }
    return units;
  }

  /// Splits an oversized paragraph into sentences, further splitting any
  /// sentence that still exceeds the budget by fixed word windows.
  List<String> _splitBySentences(String paragraph) {
    // Split after sentence-ending punctuation followed by whitespace.
    final raw = paragraph.split(RegExp(r'(?<=[.!?])\s+'));
    final sentences = raw.map((s) => s.trim()).where((s) => s.isNotEmpty);

    final units = <String>[];
    for (final sentence in sentences) {
      if (_estimateTokens(sentence) <= config.maxTokensPerChunk) {
        units.add(sentence);
      } else {
        units.addAll(_splitByWordWindow(sentence));
      }
    }
    return units;
  }

  /// Splits [text] into fixed word windows as a last resort.
  List<String> _splitByWordWindow(String text) {
    final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final windowSize = (config.maxTokensPerChunk / 1.3).floor();

    final units = <String>[];
    for (var i = 0; i < words.length; i += windowSize) {
      final end = (i + windowSize).clamp(0, words.length);
      units.add(words.sublist(i, end).join(' '));
    }
    return units;
  }

  // ---------------------------------------------------------------------------
  // Step 2 – merge units into chunks
  // ---------------------------------------------------------------------------

  List<String> _mergeIntoChunks(List<String> units) {
    final chunks = <String>[];
    final buffer = StringBuffer();
    var bufferTokens = 0;

    for (final unit in units) {
      final unitTokens = _estimateTokens(unit);
      final separator = buffer.isEmpty ? '' : '\n\n';
      final candidateTokens = bufferTokens + unitTokens + (buffer.isEmpty ? 0 : 1);

      if (bufferTokens > 0 && candidateTokens > config.maxTokensPerChunk) {
        // Flush current buffer as a chunk.
        chunks.add(buffer.toString());
        buffer.clear();
        bufferTokens = 0;
      }

      if (buffer.isNotEmpty) buffer.write(separator);
      buffer.write(unit);
      bufferTokens += unitTokens;
    }

    if (buffer.isNotEmpty) {
      final lastText = buffer.toString();
      // Merge tiny trailing fragments into the previous chunk if possible.
      if (chunks.isNotEmpty &&
          _estimateTokens(lastText) < config.minTokensPerChunk) {
        final merged = '${chunks.last}\n\n$lastText';
        if (_estimateTokens(merged) <= config.maxTokensPerChunk) {
          chunks[chunks.length - 1] = merged;
          return chunks;
        }
      }
      chunks.add(lastText);
    }

    return chunks;
  }

  // ---------------------------------------------------------------------------
  // Step 3 – overlap
  // ---------------------------------------------------------------------------

  /// Prepends the tail of each chunk to the start of the next.
  ///
  /// Overlap length = floor([ChunkingConfig.overlapFraction] ×
  /// [ChunkingConfig.maxTokensPerChunk]) tokens (≈ words / 1.3).
  List<String> _applyOverlap(List<String> chunks) {
    if (chunks.length <= 1 || config.overlapFraction <= 0) return chunks;

    final overlapTokens =
        (config.overlapFraction * config.maxTokensPerChunk).floor();
    if (overlapTokens <= 0) return chunks;

    final result = <String>[chunks.first];
    for (var i = 1; i < chunks.length; i++) {
      final tail = _tailWords(chunks[i - 1], overlapTokens);
      result.add(tail.isEmpty ? chunks[i] : '$tail\n\n${chunks[i]}');
    }
    return result;
  }

  /// Returns the last [approxTokens] tokens (approximated as words) of [text].
  String _tailWords(String text, int approxTokens) {
    final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final wordCount = (approxTokens / 1.3).floor().clamp(1, words.length);
    return words.sublist(words.length - wordCount).join(' ');
  }

  // ---------------------------------------------------------------------------
  // Token estimation
  // ---------------------------------------------------------------------------

  /// Estimates the number of LLM tokens in [text].
  ///
  /// Uses the rule-of-thumb: 1 token ≈ 0.75 words (i.e., word count × 1.3).
  /// This is a fast, dependency-free approximation suitable for budget checks.
  int _estimateTokens(String text) {
    final wordCount =
        text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    return (wordCount * 1.3).ceil();
  }
}
