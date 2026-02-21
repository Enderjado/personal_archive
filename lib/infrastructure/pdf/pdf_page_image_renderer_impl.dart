import '../../src/application/pdf_page_image_renderer.dart';
import '../../src/domain/ocr_types.dart';

/// Implementation of [PdfPageImageRenderer] using the `pdfx` package.
///
/// Renders a single PDF page to an in-memory image and returns it as an
/// [OcrInput]. Uses the same library as [PdfMetadataReaderImpl] to keep the
/// dependency footprint small (see ADR 0015).
class PdfPageImageRendererImpl implements PdfPageImageRenderer {
  @override
  Future<OcrInput> renderPage(String pdfPath, int pageNumber) async {
    // TODO: implement rendering logic
    throw UnimplementedError('PDF page rendering not yet implemented');
  }
}
