import 'package:pdfx/pdfx.dart';

import '../../src/application/pdf_page_image_renderer.dart';
import '../../src/domain/ocr_types.dart';

/// Default rendering resolution in DPI.
const int _defaultDpi = 300;

/// The base resolution of a PDF page in points-per-inch.
const double _pdfBaseDpi = 72.0;

/// Implementation of [PdfPageImageRenderer] using the `pdfx` package.
///
/// Renders a single PDF page to an in-memory PNG image and returns it as a
/// [MemoryOcrInput]. Uses the same library as [PdfMetadataReaderImpl] to keep
/// the dependency footprint small (see ADR 0015).
class PdfPageImageRendererImpl implements PdfPageImageRenderer {
  /// Creates a renderer with the given [dpi] resolution.
  ///
  /// Defaults to 300 DPI, which provides good OCR accuracy.
  PdfPageImageRendererImpl({int dpi = _defaultDpi}) : _dpi = dpi;

  final int _dpi;

  @override
  Future<OcrInput> renderPage(String pdfPath, int pageNumber) async {
    if (pageNumber < 1) {
      throw PdfRenderError(
        'Page number must be >= 1, got $pageNumber',
      );
    }

    PdfDocument? document;
    PdfPage? page;
    try {
      document = await PdfDocument.openFile(pdfPath);

      if (pageNumber > document.pagesCount) {
        throw PdfRenderError(
          'Page $pageNumber is out of range '
          '(document has ${document.pagesCount} pages)',
        );
      }

      page = await document.getPage(pageNumber);

      final scale = _dpi / _pdfBaseDpi;
      final renderWidth = (page.width * scale).round();
      final renderHeight = (page.height * scale).round();

      final pageImage = await page.render(
        width: renderWidth.toDouble(),
        height: renderHeight.toDouble(),
        format: PdfPageImageFormat.png,
        backgroundColor: '#FFFFFF',
      );

      if (pageImage == null) {
        throw PdfRenderError(
          'Rendering returned null for page $pageNumber of $pdfPath',
        );
      }

      return MemoryOcrInput(
        pageImage.bytes,
        width: pageImage.width,
        height: pageImage.height,
      );
    } on PdfRenderError {
      rethrow;
    } catch (e) {
      throw PdfRenderError(
        'Failed to render page $pageNumber of $pdfPath',
        e,
      );
    } finally {
      await page?.close();
      await document?.close();
    }
  }
}
