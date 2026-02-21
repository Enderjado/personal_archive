import 'package:pdfx/pdfx.dart';

import '../../src/application/pdf_page_image_renderer.dart';
import '../../src/domain/ocr_types.dart';
import '../../src/domain/render_configuration.dart';

/// The base resolution of a PDF page in points-per-inch.
const double _pdfBaseDpi = 72.0;

/// Implementation of [PdfPageImageRenderer] using the `pdfx` package.
///
/// Renders a single PDF page to an in-memory PNG image and returns it as a
/// [MemoryOcrInput]. Uses the same library as [PdfMetadataReaderImpl] to keep
/// the dependency footprint small (see ADR 0015).
///
/// **Temporary-file cleanup strategy** (see ADR 0015):
///
/// This renderer produces [MemoryOcrInput] (in-memory bytes), so it does not
/// write application-level temp files. The underlying `pdfx` native layer may
/// create platform temp files during rendering; passing `removeTempFile: true`
/// (the default) ensures those are deleted before `render()` returns.
///
/// If a downstream [OCREngine] adapter requires a file-based input, the
/// *adapter* is responsible for writing and cleaning up that file (typically
/// via `try`/`finally`). The renderer itself guarantees no unbounded temp-file
/// growth across a multi-page run.
class PdfPageImageRendererImpl implements PdfPageImageRenderer {
  /// Creates a renderer with the given [RenderConfiguration].
  ///
  /// Defaults to 300 DPI (via [RenderConfiguration] defaults).
  PdfPageImageRendererImpl({RenderConfiguration? config})
      : _config = config ?? const RenderConfiguration();

  final RenderConfiguration _config;

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

      final scale = _config.dpi / _pdfBaseDpi;
      final renderWidth = (page.width * scale).round();
      final renderHeight = (page.height * scale).round();

      // pdfx removes any platform temp files after rendering by default
      // (removeTempFile defaults to true internally).
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
