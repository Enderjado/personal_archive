import 'package:personal_archive/src/domain/domain.dart';

/// Port that extracts metadata from a PDF file.
///
/// Implementations live in the infrastructure layer and are injected at
/// composition root, allowing tests to substitute a fake without touching I/O.
///
/// Throws a [PdfReadError] subclass on any failure (file not found,
/// malformed PDF, unexpected I/O error).
abstract class PdfMetadataReader {
  /// Reads metadata from the PDF located at [path].
  ///
  /// Returns a [PdfMetadata] instance on success.
  /// Throws [PdfReadError] on failure.
  Future<PdfMetadata> read(String path);
}
