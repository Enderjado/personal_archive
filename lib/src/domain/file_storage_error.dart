/// Base class for all file storage errors.
sealed class FileStorageError implements Exception {
  final String message;
  final Object? cause;

  const FileStorageError(this.message, [this.cause]);

  @override
  String toString() => 'FileStorageError: $message${cause != null ? ' (Cause: $cause)' : ''}';
}

/// Thrown when a file cannot be found at the specified path.
class FileNotFoundStorageError extends FileStorageError {
  final String path;

  const FileNotFoundStorageError(this.path, [super.cause])
      : super('File not found at path: $path');
}

/// Thrown when there is an error reading or writing a file.
class FileIoStorageError extends FileStorageError {
  const FileIoStorageError(super.message, [super.cause]);
}

/// Thrown when the storage root directory is invalid or inaccessible.
class InvalidStorageRootError extends FileStorageError {
  const InvalidStorageRootError(super.message, [super.cause]);
}
