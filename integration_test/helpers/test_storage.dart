import 'dart:io';

/// Sets up a temporary directory for document storage.
Future<Directory> setupTestStorage() async {
  final tempDir = Directory.systemTemp.createTemp('personal_archive_test_');
  return tempDir;
}

/// Cleans up the temporary storage.
Future<void> cleanupTestStorage(Directory dir) async {
  if (dir.existsSync()) {
    await dir.delete(recursive: true);
  }
}
