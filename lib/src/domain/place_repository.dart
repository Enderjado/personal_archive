import 'place.dart';
import 'storage_error.dart';

/// Persistence contract for [Place] entities (unique by name).
abstract class PlaceRepository {
  /// Returns the place for [name], or creates one if none exists.
  /// Throws [StorageError] on failure (e.g. unique constraint in a race).
  Future<Place> getOrCreate(String name);

  /// Returns all places in a stable order (e.g. alphabetical by name).
  /// Throws [StorageError] on failure.
  Future<List<Place>> listAll();
}
