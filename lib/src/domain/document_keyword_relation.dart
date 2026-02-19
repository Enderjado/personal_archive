/// Link between a document and a keyword with weight and confidence for ranking.
class DocumentKeywordRelation {
  const DocumentKeywordRelation({
    required this.id,
    required this.documentId,
    required this.keywordId,
    required this.weight,
    required this.confidence,
    this.source,
  });

  final String id;
  final String documentId;
  final String keywordId;
  final double weight;
  final double confidence;
  final String? source;

  DocumentKeywordRelation copyWith({
    String? id,
    String? documentId,
    String? keywordId,
    double? weight,
    double? confidence,
    String? source,
  }) {
    return DocumentKeywordRelation(
      id: id ?? this.id,
      documentId: documentId ?? this.documentId,
      keywordId: keywordId ?? this.keywordId,
      weight: weight ?? this.weight,
      confidence: confidence ?? this.confidence,
      source: source ?? this.source,
    );
  }
}
