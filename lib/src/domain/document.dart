/// Document status in the pipeline.
enum DocumentStatus {
  imported,
  processing,
  completed,
  failed,
}

/// Represents a full imported document (PDF or other supported format).
class Document {
  const Document({
    required this.id,
    required this.title,
    required this.filePath,
    required this.status,
    this.confidenceScore,
    required this.createdAt,
    required this.updatedAt,
    this.placeId,
  });

  final String id;
  final String title;
  final String filePath;
  final DocumentStatus status;
  final double? confidenceScore;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? placeId;

  Document copyWith({
    String? id,
    String? title,
    String? filePath,
    DocumentStatus? status,
    double? confidenceScore,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? placeId,
  }) {
    return Document(
      id: id ?? this.id,
      title: title ?? this.title,
      filePath: filePath ?? this.filePath,
      status: status ?? this.status,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      placeId: placeId ?? this.placeId,
    );
  }
}
