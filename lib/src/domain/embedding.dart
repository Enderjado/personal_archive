/// Represents a semantic embedding for a document (1:1 with document).
class Embedding {
  const Embedding({
    required this.documentId,
    required this.vector,
    this.modelVersion,
    this.createdAt,
  });

  final String documentId;
  final List<double> vector;
  final String? modelVersion;
  final DateTime? createdAt;

  Embedding copyWith({
    String? documentId,
    List<double>? vector,
    String? modelVersion,
    DateTime? createdAt,
  }) {
    return Embedding(
      documentId: documentId ?? this.documentId,
      vector: vector ?? this.vector,
      modelVersion: modelVersion ?? this.modelVersion,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

