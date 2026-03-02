/// Represents a detected place prediction from LLM processing.
///
/// A place is a geographic location (city, region, landmark, country, etc.)
/// mentioned in text. This value object captures the detected place name
/// and an optional confidence score indicating the model's certainty.
class PlacePrediction {
  /// The name of the detected place.
  final String placeName;

  /// Optional confidence score (0.0 to 1.0) indicating certainty of detection.
  ///
  /// If null, the implementation did not provide a confidence score.
  /// A value closer to 1.0 suggests higher confidence in the prediction.
  final double? confidence;

  /// Creates a new [PlacePrediction] with the given [placeName] and optional [confidence].
  const PlacePrediction({
    required this.placeName,
    this.confidence,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlacePrediction &&
          runtimeType == other.runtimeType &&
          placeName == other.placeName &&
          confidence == other.confidence;

  @override
  int get hashCode => placeName.hashCode ^ confidence.hashCode;

  @override
  String toString() => 'PlacePrediction(placeName: $placeName, confidence: $confidence)';
}

/// Represents a detected keyword or key term from LLM processing.
///
/// A keyword is a significant term, concept, or phrase that represents
/// a main topic discussed in the source text. This value object captures
/// the keyword itself and an optional confidence score.
class KeywordPrediction {
  /// The keyword or key term.
  final String keyword;

  /// Optional confidence score (0.0 to 1.0) indicating certainty of detection.
  ///
  /// If null, the implementation did not provide a confidence score.
  /// A value closer to 1.0 suggests higher confidence in the prediction.
  final double? confidence;

  /// Creates a new [KeywordPrediction] with the given [keyword] and optional [confidence].
  const KeywordPrediction({
    required this.keyword,
    this.confidence,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KeywordPrediction &&
          runtimeType == other.runtimeType &&
          keyword == other.keyword &&
          confidence == other.confidence;

  @override
  int get hashCode => keyword.hashCode ^ confidence.hashCode;

  @override
  String toString() => 'KeywordPrediction(keyword: $keyword, confidence: $confidence)';
}

/// Metadata about an LLM operation and its response.
///
/// This value object captures contextual information about an LLM
/// operation's execution, useful for diagnostics, logging, and
/// optimizing future LLM calls.
class LLMOperationMetadata {
  /// The duration the LLM operation took to complete.
  final Duration processingTime;

  /// Optional model identifier or version used for the operation.
  ///
  /// Useful for tracking which model generated a particular result.
  final String? modelIdentifier;

  /// Optional diagnostic message from the LLM runtime.
  final String? diagnosticMessage;

  /// Creates a new [LLMOperationMetadata] with processing details.
  const LLMOperationMetadata({
    required this.processingTime,
    this.modelIdentifier,
    this.diagnosticMessage,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LLMOperationMetadata &&
          runtimeType == other.runtimeType &&
          processingTime == other.processingTime &&
          modelIdentifier == other.modelIdentifier &&
          diagnosticMessage == other.diagnosticMessage;

  @override
  int get hashCode =>
      processingTime.hashCode ^
      modelIdentifier.hashCode ^
      diagnosticMessage.hashCode;

  @override
  String toString() =>
      'LLMOperationMetadata(processingTime: $processingTime, modelIdentifier: $modelIdentifier, diagnosticMessage: $diagnosticMessage)';
}

