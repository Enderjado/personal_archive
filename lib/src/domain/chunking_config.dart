/// Configuration for the [Chunker] implementation.
///
/// Numeric defaults are derived from ADR 0018 (Chunking strategy and token
/// budget): a conservative 4,096-token effective context window with ~25%
/// reserved for prompts, leaving ~3,000 tokens for document content and
/// a target chunk size of 1,000–1,500 tokens.
class ChunkingConfig {
  const ChunkingConfig({
    this.maxTokensPerChunk = 1500,
    this.minTokensPerChunk = 100,
    this.overlapFraction = 0.1,
  });

  /// Maximum number of tokens per chunk (default: 1,500).
  ///
  /// Keeps each LLM request comfortably within the effective context window
  /// as specified in ADR 0018.
  final int maxTokensPerChunk;

  /// Minimum number of tokens a chunk must contain to be emitted on its own.
  ///
  /// Short trailing fragments below this threshold are merged into the
  /// preceding chunk rather than emitted as a standalone chunk.
  final int minTokensPerChunk;

  /// Fraction of [maxTokensPerChunk] to repeat at the start of each chunk
  /// as an overlap with the previous chunk (default: 0.1 = 10%).
  ///
  /// A small overlap preserves continuity across chunk boundaries for
  /// summarisation and keyword tasks (see ADR 0018).
  final double overlapFraction;
}
