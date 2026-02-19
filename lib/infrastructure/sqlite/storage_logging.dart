/// Logging and timing utilities for the storage layer.
///
/// This abstraction is intentionally minimal and pluggable so that
/// it can later be wired to a more fully featured logging or metrics
/// backend without changing repository and migration code.
abstract class StorageLogger {
  /// Records a write operation against a storage table.
  ///
  /// Implementations are expected to log or emit metrics using the
  /// provided metadata. [recordCount] should represent the number of
  /// rows affected or attempted by the operation.
  void logWrite({
    required String operation,
    required String table,
    required int recordCount,
    required Duration duration,
  });

  /// Records a read operation against a storage table.
  ///
  /// Implementations may choose to emit all read events or only a
  /// subset (for example, slow reads) depending on configuration.
  void logRead({
    required String operation,
    required String table,
    required Duration duration,
  });
}

/// No-op implementation used when storage logging is not configured.
///
/// This allows repositories and the migration runner to depend on
/// [StorageLogger] without forcing a concrete logger in every
/// environment.
class NoOpStorageLogger implements StorageLogger {
  const NoOpStorageLogger();

  @override
  void logWrite({
    required String operation,
    required String table,
    required int recordCount,
    required Duration duration,
  }) {
    // Intentionally empty.
  }

  @override
  void logRead({
    required String operation,
    required String table,
    required Duration duration,
  }) {
    // Intentionally empty.
  }
}

typedef _AsyncOperation<T> = Future<T> Function();

/// Measures the duration of a write operation and reports it via [logger].
///
/// The wrapped [action] is awaited and its result is returned. The logger
/// is notified regardless of whether [action] completes successfully or
/// throws.
Future<T> timeWriteOperation<T>({
  required StorageLogger logger,
  required String operation,
  required String table,
  required int recordCount,
  required _AsyncOperation<T> action,
}) async {
  final stopwatch = Stopwatch()..start();
  try {
    return await action();
  } finally {
    stopwatch.stop();
    logger.logWrite(
      operation: operation,
      table: table,
      recordCount: recordCount,
      duration: stopwatch.elapsed,
    );
  }
}

/// Measures the duration of a read operation and reports it via [logger].
///
/// The wrapped [action] is awaited and its result is returned. The logger
/// is notified regardless of whether [action] completes successfully or
/// throws.
Future<T> timeReadOperation<T>({
  required StorageLogger logger,
  required String operation,
  required String table,
  Duration slowLogThreshold = const Duration(milliseconds: 75),
  required _AsyncOperation<T> action,
}) async {
  final stopwatch = Stopwatch()..start();
  try {
    return await action();
  } finally {
    stopwatch.stop();
    final duration = stopwatch.elapsed;
    if (duration >= slowLogThreshold) {
      logger.logRead(
        operation: operation,
        table: table,
        duration: duration,
      );
    }
  }
}

