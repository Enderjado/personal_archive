import '../domain/text_processing_config.dart';
import '../domain/text_processor.dart';

/// A concrete [TextProcessor] that cleans raw OCR output in multiple passes.
///
/// Each pass targets a specific class of noise. Passes are applied in order:
/// 1. Whitespace and line-break normalisation (always active).
/// 2. Hyphenation rejoining – merges words split across lines by a hyphen.
/// 3. Header/footer stripping – removes lines matching patterns in [config].
///
/// This class is pure; given the same [config] and the same input the output
/// is always identical, making it straightforward to test.
class OcrTextProcessor implements TextProcessor {
  const OcrTextProcessor({this.config = const TextProcessingConfig()});

  final TextProcessingConfig config;

  @override
  String clean(String raw) {
    if (raw.trim().isEmpty) return '';

    var text = raw;
    text = _normaliseLineEndings(text);
    text = _rejoinHyphenation(text);
    text = _normaliseWhitespace(text);
    text = _trimLines(text);
    text = _collapseBlankLines(text);
    text = _stripHeadersAndFooters(text);
    return text.trim();
  }

  // ---------------------------------------------------------------------------
  // Pass 1 – whitespace and line-break normalisation
  // ---------------------------------------------------------------------------

  /// Converts all CRLF and CR line endings to a single LF.
  String _normaliseLineEndings(String text) =>
      text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

  /// Collapses runs of horizontal whitespace (spaces, tabs) to a single space
  /// on each line, preserving line breaks.
  String _normaliseWhitespace(String text) {
    // Replace each run of horizontal whitespace with one space.
    return text.replaceAll(RegExp(r'[ \t]+'), ' ');
  }

  /// Removes leading and trailing spaces from every line.
  String _trimLines(String text) {
    return text.split('\n').map((line) => line.trim()).join('\n');
  }

  /// Collapses runs of more than two consecutive blank lines into two,
  /// preserving intentional paragraph breaks.
  String _collapseBlankLines(String text) {
    return text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  }

  // ---------------------------------------------------------------------------
  // Pass 2 – hyphenation rejoining
  // ---------------------------------------------------------------------------

  /// Merges words that OCR split across two lines using a hyphen.
  ///
  /// Matches a letter, a hyphen, a newline, and another letter, then removes
  /// the hyphen and newline so the two parts form one word.
  ///
  /// Examples:
  /// - `recogni-\ntion`  →  `recognition`
  /// - `first-\nclass`   →  `firstclass`  (intentional hyphens are rare in OCR
  ///   body text; a follow-up dictionary pass may restore them if needed)
  String _rejoinHyphenation(String text) {
    return text.replaceAllMapped(
      RegExp(r'([a-zA-Z])-\n([a-zA-Z])'),
      (m) => '${m[1]}${m[2]}',
    );
  }

  // ---------------------------------------------------------------------------
  // Pass 3 – header and footer stripping
  // ---------------------------------------------------------------------------

  /// Removes any line whose entire trimmed content matches a header or footer
  /// pattern defined in [config].
  ///
  /// Matching is full-line: a pattern must cover the whole line, not just a
  /// substring. This prevents accidental removal of lines that merely
  /// *contain* a common word.
  String _stripHeadersAndFooters(String text) {
    if (config.headerPatterns.isEmpty && config.footerPatterns.isEmpty) {
      return text;
    }

    final allPatterns = [
      ...config.headerPatterns,
      ...config.footerPatterns,
    ].map((p) => RegExp('^$p\$')).toList();

    final lines = text.split('\n');
    final filtered = lines.where((line) {
      final trimmed = line.trim();
      return !allPatterns.any((re) => re.hasMatch(trimmed));
    });
    return filtered.join('\n');
  }
}
