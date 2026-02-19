/// Represents a single page of a document (e.g. OCR result, text content).
class Page {
  const Page({
    required this.id,
    required this.documentId,
    required this.pageNumber,
    this.rawText,
    this.processedText,
    this.ocrConfidence,
  });

  final String id;
  final String documentId;
  final int pageNumber;
  final String? rawText;
  final String? processedText;
  final double? ocrConfidence;

  Page copyWith({
    String? id,
    String? documentId,
    int? pageNumber,
    String? rawText,
    String? processedText,
    double? ocrConfidence,
  }) {
    return Page(
      id: id ?? this.id,
      documentId: documentId ?? this.documentId,
      pageNumber: pageNumber ?? this.pageNumber,
      rawText: rawText ?? this.rawText,
      processedText: processedText ?? this.processedText,
      ocrConfidence: ocrConfidence ?? this.ocrConfidence,
    );
  }
}
