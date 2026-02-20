import 'package:pdfx/pdfx.dart';

import '../../src/application/pdf_metadata_reader.dart';
import '../../src/domain/pdf_metadata.dart';

/// Implementation of [PdfMetadataReader] using the `pdfx` package.
class PdfMetadataReaderImpl implements PdfMetadataReader {
  @override
  Future<PdfMetadata> read(String path) async {
    PdfDocument? document;
    try {
      document = await PdfDocument.openFile(path);
      return PdfMetadata(pageCount: document.pagesCount);
    } catch (e) {
      throw PdfReadError('Failed to read PDF metadata from $path', e);
    } finally {
      // Ensure the document is closed to free up resources.
      // pdfx does not have a close() method on PdfDocument, it relies on garbage collection
      // or native memory management depending on the platform.
      // If a close/dispose method becomes available in future versions, call it here.
    }
  }
}
