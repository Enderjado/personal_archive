import 'dart:io';

import '../domain/domain.dart';

/// Validates PDF files before importing them into the system.
class ImportValidator {
  const ImportValidator({
    this.config = const ImportConfiguration(),
  });

  final ImportConfiguration config;

  /// Validates the file at the given [path].
  ///
  /// Throws an [ImportValidationError] if validation fails.
  Future<void> validateFile(String path) async {
    final file = File(path);

    // 1. Check if file exists and is a regular file
    if (!await file.exists()) {
      throw FileDoesNotExistError(path);
    }

    // 2. Check if file is readable (by trying to open it for reading)
    try {
      final randomAccessFile = await file.open(mode: FileMode.read);
      await randomAccessFile.close();
    } catch (e) {
      throw FileNotReadableError(path);
    }

    // 3. Check file extension
    if (!path.toLowerCase().endsWith('.pdf')) {
      throw InvalidPdfFormatError(path);
    }

    // 4. Check file size
    final sizeBytes = await file.length();
    if (sizeBytes > config.maxFileSizeBytes) {
      throw FileTooLargeError(path, sizeBytes, config.maxFileSizeBytes);
    }
  }
}
