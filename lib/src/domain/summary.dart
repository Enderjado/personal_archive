/// Represents an automatically generated summary for a document (1:1 with document).
class Summary {
  const Summary({
    required this.documentId,
    required this.text,
    required this.modelVersion,
    required this.createdAt,
  });

  final String documentId;
  final String text;
  final String modelVersion;
  final DateTime createdAt;

  Summary copyWith({
    String? documentId,
    String? text,
    String? modelVersion,
    DateTime? createdAt,
  }) {
    return Summary(
      documentId: documentId ?? this.documentId,
      text: text ?? this.text,
      modelVersion: modelVersion ?? this.modelVersion,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
