/// Typed error for storage layer failures (e.g. SQLite); avoids leaking raw exceptions.
abstract class StorageError implements Exception {
  const StorageError();
  String get message;
}

/// Requested entity was not found.
class StorageNotFoundError extends StorageError {
  const StorageNotFoundError({this.resource, this.id});
  final String? resource;
  final String? id;
  @override
  String get message => 'Not found${resource != null ? ': $resource' : ''}${id != null ? ' ($id)' : ''}';
}

/// Constraint or foreign key violation.
class StorageConstraintError extends StorageError {
  const StorageConstraintError({this.detail});
  final String? detail;
  @override
  String get message => 'Constraint violation${detail != null ? ': $detail' : ''}';
}

/// Other storage failure (e.g. I/O, low-level driver error).
class StorageUnknownError extends StorageError {
  const StorageUnknownError(this.cause);
  final Object cause;
  @override
  String get message => cause.toString();
}
