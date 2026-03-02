import 'llm_types.dart';

/// Abstract interface for local LLM operations.
///
/// This service provides a stable, platform-agnostic contract for interacting
/// with the local large language model (llama.cpp). It hides all FFI and runtime
/// details from the domain layer, ensuring that intelligence features are
/// decoupled from the underlying LLM implementation.
///
/// The service is designed to be fully mockable for unit tests and extensible
/// for future LLM capabilities without breaking existing contracts.
abstract class LLMService {
  /// Generates a concise summary of the provided text.
  ///
  /// Attempts to extract the most salient information from [text] and
  /// condense it while preserving key meaning.
  ///
  /// **Input expectations:**
  /// - Text should be reasonably sized (typically < 10,000 characters).
  /// - Behavior with very large texts is implementation-dependent.
  ///
  /// **Error semantics:**
  /// - May throw if the text is malformed or unprocessable.
  /// - May throw if the LLM encounters a runtime error.
  ///
  /// Returns a [Future] that resolves to a non-empty summary string.
  Future<String> summarize(String text);

  /// Extracts key terms or concepts from the provided text.
  ///
  /// Identifies significant keywords or phrases that represent the main
  /// topics and entities discussed in [text].
  ///
  /// **Input expectations:**
  /// - Text should be reasonably sized (typically < 10,000 characters).
  /// - Behavior with very large texts is implementation-dependent.
  ///
  /// **Error semantics:**
  /// - May throw if the text is malformed or unprocessable.
  /// - May throw if the LLM encounters a runtime error.
  ///
  /// Returns a [Future] that resolves to a list of keyword strings.
  /// The list may be empty if no keywords are detected.
  Future<List<String>> extractKeywords(String text);

  /// Detects place names mentioned in the provided text.
  ///
  /// Identifies geographic locations (cities, regions, landmarks, etc.)
  /// referenced in [text] and optionally provides confidence scores.
  ///
  /// **Input expectations:**
  /// - Text should be reasonably sized (typically < 10,000 characters).
  /// - Behavior with very large texts is implementation-dependent.
  ///
  /// **Error semantics:**
  /// - May throw if the text is malformed or unprocessable.
  /// - May throw if the LLM encounters a runtime error.
  ///
  /// Returns a [Future] that resolves to a list of detected places.
  /// The list may be empty if no places are detected.
  Future<List<PlacePrediction>> detectPlaces(String text);
}
