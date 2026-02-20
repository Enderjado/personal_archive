/// Typed error for PDF import validation failures.
abstract class ImportValidationError implements Exception {
  const ImportValidationError();

  /// A machine-readable code for the error.
  String get code;

  /// A human-readable message describing the error.
  String get message;

  @override
  String toString() => 'ImportValidationError($code): $message';
}

/// Error thrown when the file does not exist or is not a regular file.
class FileDoesNotExistError extends ImportValidationError {
  const FileDoesNotExistError(this.path);
  final String path;

  @override
  String get code => 'file_not_found';

  @override
  String get message =>
      'The file at $path does not exist or is not a regular file.';
}

/// Error thrown when the file cannot be read.
class FileNotReadableError extends ImportValidationError {
  const FileNotReadableError(this.path);
  final String path;

  @override
  String get code => 'file_not_readable';

  @override
  String get message => 'The file at $path cannot be read.';
}

/// Error thrown when the file is not a valid PDF.
class InvalidPdfFormatError extends ImportValidationError {
  const InvalidPdfFormatError(this.path);
  final String path;

  @override
  String get code => 'invalid_pdf_format';

  @override
  String get message => 'The file at $path is not a valid PDF.';
}

/// Error thrown when the file exceeds the maximum allowed size.
class FileTooLargeError extends ImportValidationError {
  const FileTooLargeError(this.path, this.sizeBytes, this.maxSizeBytes);
  final String path;
  final int sizeBytes;
  final int maxSizeBytes;

  @override
  String get code => 'file_too_large';

  @override
  String get message =>
      'The file at $path is too large ($sizeBytes bytes). Maximum allowed size is $maxSizeBytes bytes.';
}

/// Error thrown when the PDF has too many pages.
class TooManyPagesError extends ImportValidationError {
  const TooManyPagesError(this.path, this.pageCount, this.maxPageCount);
  final String path;
  final int pageCount;
  final int maxPageCount;

  @override
  String get code => 'too_many_pages';

  @override
  String get message =>
      'The PDF at $path has too many pages ($pageCount). Maximum allowed is $maxPageCount pages.';
}
