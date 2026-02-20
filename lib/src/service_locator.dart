import 'package:personal_archive/infrastructure/pdf/pdf_metadata_reader_impl.dart';
import 'package:personal_archive/src/application/pdf_metadata_reader.dart';

/// Simple service locator for dependency injection.
///
/// Provides singleton access to interface implementations. When the project
/// grows, this can be replaced by a dedicated DI package (e.g. `get_it`).
class ServiceLocator {
  ServiceLocator._();

  static final ServiceLocator instance = ServiceLocator._();

  PdfMetadataReader? _pdfMetadataReader;

  /// Returns the registered [PdfMetadataReader] implementation.
  PdfMetadataReader get pdfMetadataReader {
    return _pdfMetadataReader ??= PdfMetadataReaderImpl();
  }

  /// Overrides the [PdfMetadataReader] instance (useful for testing).
  set pdfMetadataReader(PdfMetadataReader reader) {
    _pdfMetadataReader = reader;
  }

  /// Resets all registrations. Intended for test teardown only.
  void reset() {
    _pdfMetadataReader = null;
  }
}
