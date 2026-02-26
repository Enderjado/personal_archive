import 'package:personal_archive/infrastructure/pdf/pdf_metadata_reader_impl.dart';
import 'package:personal_archive/infrastructure/pdf/pdf_page_image_renderer_impl.dart';
import 'package:personal_archive/src/application/application.dart';
import 'package:personal_archive/src/domain/ocr_config.dart';
import 'package:personal_archive/src/domain/page_repository.dart';

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
  PageRepository? _pageRepository;
  TextProcessingService? _textProcessingService;
  OcrConfig _ocrConfig = const OcrConfig();

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
      config: _ocrConfig,
    );
  }

  /// Overrides the [PdfPageImageRenderer] instance (useful for testing).
  set pdfPageImageRenderer(PdfPageImageRenderer renderer) {
    _pdfPageImageRenderer = renderer;
  }

  /// Returns the current [OcrConfig].
  OcrConfig get ocrConfig => _ocrConfig;

  /// Overrides the [OcrConfig].
  ///
  /// If a [PdfPageImageRenderer] has already been created, it will continue
  /// using the old configuration. Reset the renderer to pick up changes.
  set ocrConfig(OcrConfig config) {
    _ocrConfig = config;
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

  /// Returns the registered [PageRepository] implementation.
  ///
  /// Must be set via the setter before first access; no default implementation
  /// can be created without a database handle.
  PageRepository get pageRepository {
    assert(
      _pageRepository != null,
      'PageRepository has not been registered. '
      'Call ServiceLocator.instance.pageRepository = ... before use.',
    );
    return _pageRepository!;
  }

  /// Overrides the [PageRepository] instance.
  set pageRepository(PageRepository repository) {
    _pageRepository = repository;
    _textProcessingService = null; // force re-creation with new repository
  }

  /// Returns the registered [TextProcessingService] implementation.
  ///
  /// Lazily constructed from [pageRepository] and [OcrTextProcessor] on first
  /// access. Override via the setter to supply a custom implementation
  /// (e.g. in tests).
  TextProcessingService get textProcessingService {
    return _textProcessingService ??= TextProcessingServiceImpl(
      pageRepository: pageRepository,
      textProcessor: const OcrTextProcessor(),
    );
  }

  /// Overrides the [TextProcessingService] instance (useful for testing).
  set textProcessingService(TextProcessingService service) {
    _textProcessingService = service;
  }

  /// Resets all registrations. Intended for test teardown only.
  void reset() {
    _pdfMetadataReader = null;
    _pdfPageImageRenderer = null;
    _importValidator = null;
    _pageRepository = null;
    _textProcessingService = null;
    _ocrConfig = const OcrConfig();
  }
}
