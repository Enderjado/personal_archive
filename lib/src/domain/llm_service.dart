import 'llm_types.dart';

/// Abstract interface for local LLM operations.
///
/// This service provides a stable, platform-agnostic contract for interacting
/// with the local large language model (llama.cpp). It hides all FFI and runtime
/// details from the domain layer, ensuring that intelligence features are
/// decoupled from the underlying LLM implementation.
///
/// **Design Philosophy**
///
/// The `LLMService` is intentionally minimal and focused, providing only the
/// essential operations needed by the Intelligence pipeline (v0.3):
/// - Summarization (condensing text to key points)
/// - Keyword extraction (identifying significant terms)
/// - Place detection (recognizing geographic locations)
///
/// This minimalism ensures the interface is:
/// - Easy to understand and implement
/// - Fully mockable for testing
/// - Future-proof without over-engineering
///
/// **Error Handling Strategy**
///
/// The service uses **exceptions** for error signaling. Implementations should:
/// - Throw exceptions when the LLM cannot process input (malformed text, runtime errors).
/// - Not catch exceptions internally; propagate them to callers.
/// - Use specific exception types when possible (e.g., `ArgumentError` for invalid input).
/// - Include meaningful error messages to aid debugging.
///
/// Callers are responsible for handling exceptions, either by catching them
/// or letting them bubble up to the application's error handling layer.
///
/// **Future Extensibility**
///
/// Methods for new capabilities (e.g., embedding generation, entity extraction)
/// can be added to this interface without breaking existing implementations, as
/// new methods will have default declarations that existing implementations can
/// optionally override. The interface is designed to grow with minimal disruption.
///
/// **Implementation Notes**
///
/// - All methods are asynchronous (`Future`-returning) to accommodate network or
///   I/O-bound operations in future extensions.
/// - Methods should be deterministic for the same input and configuration,
///   allowing mock implementations to provide predictable responses for tests.
/// - Implementations must handle large or malformed input gracefully.
///
/// The service is designed to be fully mockable for unit tests and extensible
/// for future LLM capabilities without breaking existing contracts.
abstract class LLMService {
  /// Generates a concise summary of the provided text.
  ///
  /// Attempts to extract the most salient information from [text] and
  /// condense it while preserving key meaning.
  ///
  /// **Input Expectations:**
  /// - Text should be reasonably sized (typically < 10,000 characters).
  /// - Non-empty text is recommended; behavior with empty strings is
  ///   implementation-dependent (may return empty string or throw).
  /// - Behavior with very large texts (> 100,000 characters) is
  ///   implementation-dependent and may result in truncation or errors.
  ///
  /// **Determinism:**
  /// - For a given input and fixed LLM configuration, the output should be
  ///   deterministic (or near-deterministic depending on implementation).
  /// - This guarantee enables mock implementations to provide predictable
  ///   responses for testing.
  ///
  /// **Error Semantics:**
  /// Throws an exception in the following cases:
  /// - Text is malformed, encoding issues, or cannot be processed.
  /// - The underlying LLM encounters a runtime error.
  /// - The text exceeds implementation-defined size limits.
  ///
  /// Returns a [Future] that resolves to a non-empty summary string.
  /// The summary should preserve the original text's meaning and key points.
  Future<String> summarize(String text);

  /// Extracts key terms or concepts from the provided text.
  ///
  /// Identifies significant keywords or phrases that represent the main
  /// topics and entities discussed in [text].
  ///
  /// **Input Expectations:**
  /// - Text should be reasonably sized (typically < 10,000 characters).
  /// - Non-empty text is recommended; behavior with empty strings is
  ///   implementation-dependent (may return empty list or throw).
  /// - Behavior with very large texts (> 100,000 characters) is
  ///   implementation-dependent and may result in truncation or errors.
  ///
  /// **Determinism:**
  /// - For a given input and fixed LLM configuration, the output should be
  ///   deterministic (or near-deterministic depending on implementation).
  /// - This guarantee enables mock implementations to provide predictable
  ///   responses for testing.
  ///
  /// **Error Semantics:**
  /// Throws an exception in the following cases:
  /// - Text is malformed, encoding issues, or cannot be processed.
  /// - The underlying LLM encounters a runtime error.
  /// - The text exceeds implementation-defined size limits.
  ///
  /// Returns a [Future] that resolves to a list of keyword strings.
  /// The list may be empty if no keywords are detected. Keywords are
  /// typically in the original language of the input text.
  Future<List<String>> extractKeywords(String text);

  /// Detects place names mentioned in the provided text.
  ///
  /// Identifies geographic locations (cities, regions, landmarks, countries, etc.)
  /// referenced in [text] and optionally provides confidence scores for each.
  ///
  /// **Input Expectations:**
  /// - Text should be reasonably sized (typically < 10,000 characters).
  /// - Non-empty text is recommended; behavior with empty strings is
  ///   implementation-dependent (may return empty list or throw).
  /// - Behavior with very large texts (> 100,000 characters) is
  ///   implementation-dependent and may result in truncation or errors.
  /// - Place names are expected to match standardized geographic names
  ///   (e.g., "New York" rather than informal local names).
  ///
  /// **Determinism:**
  /// - For a given input and fixed LLM configuration, the detected places
  ///   and their order should be deterministic (or near-deterministic).
  /// - This guarantee enables mock implementations to provide predictable
  ///   responses for testing.
  ///
  /// **Error Semantics:**
  /// Throws an exception in the following cases:
  /// - Text is malformed, encoding issues, or cannot be processed.
  /// - The underlying LLM encounters a runtime error.
  /// - The text exceeds implementation-defined size limits.
  ///
  /// Returns a [Future] that resolves to a list of [PlacePrediction] objects.
  /// The list may be empty if no places are detected. Confidence scores,
  /// if provided, indicate the model's certainty in each detection.
  Future<List<PlacePrediction>> detectPlaces(String text);
}
