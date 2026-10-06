import '../entities/saved_location.dart';

/// Offline-first store of the user's [SavedLocation]s.
///
/// Every write is persisted locally first and then pushed to Firestore at
/// `users/{uid}/locations/{locationId}`. A failed push never fails the
/// write; the row stays pending and is retried by [syncPending].
abstract class SavedLocationRepository {
  Future<List<SavedLocation>> getLocations(String userId);

  /// Inserts or replaces [location] (matched by id).
  Future<SavedLocation> save(SavedLocation location);

  Future<void> delete(String userId, String id);

  /// Pushes rows that have not reached Firestore yet (including pending
  /// deletes). Returns how many operations were pushed.
  Future<int> syncPending(String userId);

  /// Merges remote rows missing locally (e.g. after reinstall, or on web
  /// where Firestore is the only durable store). Returns the merged list.
  Future<List<SavedLocation>> refreshFromRemote(String userId);
}
