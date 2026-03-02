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
