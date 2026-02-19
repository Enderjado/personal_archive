import 'keyword.dart';
import 'storage_error.dart';

/// Persistence contract for [Keyword] entities (unique by value and type).
abstract class KeywordRepository {
  /// Returns the keyword for [value] and [type], or creates one if none exists.
  /// Throws [StorageError] on failure (e.g. unique constraint in a race).
  Future<Keyword> getOrCreate(String value, String type);

  /// Increments [Keyword.globalFrequency] for the given [keywordId].
  /// Throws [StorageError] on failure.
  Future<void> incrementGlobalFrequency(String keywordId);
}
