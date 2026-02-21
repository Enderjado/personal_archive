import 'package:personal_archive/infrastructure/pdf/pdf_metadata_reader_impl.dart';
import 'package:personal_archive/infrastructure/pdf/pdf_page_image_renderer_impl.dart';
import 'package:personal_archive/src/application/application.dart';
import 'package:personal_archive/src/domain/render_configuration.dart';

/// Simple service locator for dependency injection.
///
/// Provides singleton access to interface implementations. When the project
/// grows, this can be replaced by a dedicated DI package (e.g. `get_it`).
class ServiceLocator {
  ServiceLocator._();

  static final ServiceLocator instance = ServiceLocator._();

  PdfMetadataReader? _pdfMetadataReader;
  PdfPageImageRenderer? _pdfPageImageRenderer;
  ImportValidator? _importValidator;
  RenderConfiguration _renderConfiguration = const RenderConfiguration();

  /// Returns the registered [PdfMetadataReader] implementation.
  PdfMetadataReader get pdfMetadataReader {
    return _pdfMetadataReader ??= PdfMetadataReaderImpl();
  }

  /// Overrides the [PdfMetadataReader] instance (useful for testing).
  set pdfMetadataReader(PdfMetadataReader reader) {
    _pdfMetadataReader = reader;
  }

  /// Returns the registered [PdfPageImageRenderer] implementation.
  PdfPageImageRenderer get pdfPageImageRenderer {
    return _pdfPageImageRenderer ??= PdfPageImageRendererImpl(
      config: _renderConfiguration,
    );
  }

  /// Overrides the [PdfPageImageRenderer] instance (useful for testing).
  set pdfPageImageRenderer(PdfPageImageRenderer renderer) {
    _pdfPageImageRenderer = renderer;
  }

  /// Returns the current [RenderConfiguration].
  RenderConfiguration get renderConfiguration => _renderConfiguration;

  /// Overrides the [RenderConfiguration].
  ///
  /// If a [PdfPageImageRenderer] has already been created, it will continue
  /// using the old configuration. Reset the renderer to pick up changes.
  set renderConfiguration(RenderConfiguration config) {
    _renderConfiguration = config;
    _pdfPageImageRenderer = null; // force re-creation with new config
  }

  /// Returns the registered [ImportValidator] implementation.
  ImportValidator get importValidator {
    return _importValidator ??= ImportValidator(
      pdfMetadataReader: pdfMetadataReader,
    );
  }

  /// Overrides the [ImportValidator] instance (useful for testing).
  set importValidator(ImportValidator validator) {
    _importValidator = validator;
  }

  /// Resets all registrations. Intended for test teardown only.
  void reset() {
    _pdfMetadataReader = null;
    _pdfPageImageRenderer = null;
    _importValidator = null;
    _renderConfiguration = const RenderConfiguration();
  }
}
