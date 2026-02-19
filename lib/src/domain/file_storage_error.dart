/// Base class for all file storage errors.
abstract class FileStorageError implements Exception {
  final String message;
  final Object? cause;

  const FileStorageError(this.message, [this.cause]);

  @override
  String toString() => 'FileStorageError: $message${cause != null ? ' (Cause: $cause)' : ''}';
}

/// Thrown when a file cannot be found at the specified path.
class FileNotFoundStorageError extends FileStorageError {
  final String path;

  const FileNotFoundStorageError(this.path, [Object? cause])
      : super('File not found at path: $path', cause);
}

/// Thrown when there is an error reading or writing a file.
class FileIoStorageError extends FileStorageError {
  const FileIoStorageError(String message, [Object? cause]) : super(message, cause);
}

/// Thrown when the storage root directory is invalid or inaccessible.
class InvalidStorageRootError extends FileStorageError {
  const InvalidStorageRootError(String message, [Object? cause]) : super(message, cause);
}
