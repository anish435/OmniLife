import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/errors/failures.dart';
import '../../domain/entities/saved_location.dart';
import '../../domain/repositories/saved_location_repository.dart';
import '../datasources/local/saved_location_local_store.dart';
import '../datasources/remote/user_doc_remote.dart';
import '../models/saved_location_model.dart';

/// Local-first [SavedLocationRepository].
///
/// Write path: persist locally (marked pending) -> return immediately ->
/// push to `users/{uid}/locations/{id}` in the background and mark synced
/// on success. Failures leave the row pending for [syncPending].
///
/// On web the local store is in-memory, so Firestore is the durable store;
/// callers should [refreshFromRemote] on load there.
class SavedLocationRepositoryImpl implements SavedLocationRepository {
  SavedLocationRepositoryImpl({
    SavedLocationLocalStore? localStore,
    UserDocRemote? remote,
  }) : _local =
           localStore ??
           (kIsWeb ? InMemorySavedLocationStore() : SqliteSavedLocationStore()),
       _remote = remote ?? FirestoreUserDocRemote();

  static const collection = 'locations';

  final SavedLocationLocalStore _local;
  final UserDocRemote _remote;
  final Set<Future<void>> _inFlight = {};

  /// Completes when all background pushes started so far have finished.
  /// Mainly for tests and for flushing before sign-out.
  Future<void> flush() async {
    while (_inFlight.isNotEmpty) {
      await Future.wait(_inFlight.toList());
    }
  }

  void _track(Future<void> f) {
    late final Future<void> guarded;
    guarded = f
        .catchError((Object _) {})
        .whenComplete(() => _inFlight.remove(guarded));
    _inFlight.add(guarded);
  }

  @override
  Future<List<SavedLocation>> getLocations(String userId) async {
    try {
      return await _local.getAll(userId);
    } catch (e) {
      throw DatabaseFailure('Failed to load saved places: $e');
    }
  }

  @override
  Future<SavedLocation> save(SavedLocation location) async {
    try {
      await _local.upsert(location, synced: false);
    } catch (e) {
      throw DatabaseFailure('Failed to save place: $e');
    }
    _track(_push(location));
    return location;
  }

  Future<void> _push(SavedLocation location) async {
    await _remote.set(
      location.userId,
      collection,
      location.id,
      SavedLocationModel.fromEntity(location).toFirestoreMap(),
    );
    await _local.markSynced(location.id);
  }

  @override
  Future<void> delete(String userId, String id) async {
    try {
      await _local.markDeleted(id);
    } catch (e) {
      throw DatabaseFailure('Failed to delete place: $e');
    }
    _track(_pushDelete(userId, id));
  }

  Future<void> _pushDelete(String userId, String id) async {
    await _remote.delete(userId, collection, id);
    await _local.purge(id);
  }

  @override
  Future<int> syncPending(String userId) async {
    final pending = await _local.getPending(userId);
    var pushed = 0;
    for (final change in pending) {
      try {
        if (change.deleted) {
          await _pushDelete(userId, change.location.id);
        } else {
          await _push(change.location);
        }
        pushed++;
      } catch (_) {
        // Still offline / rejected: keep pending, try again next time.
      }
    }
    return pushed;
  }

  @override
  Future<List<SavedLocation>> refreshFromRemote(String userId) async {
    try {
      final docs = await _remote.list(userId, collection);
      final local = await _local.getAll(userId);
      final pendingIds = {
        for (final c in await _local.getPending(userId)) c.location.id,
      };
      final byId = {for (final l in local) l.id: l};
      for (final doc in docs) {
        try {
          final remote = SavedLocationModel.fromFirestoreMap(userId, {
            ...doc,
            // list() reports the document id under 'id'.
            'id': doc['id'],
          });
          if (pendingIds.contains(remote.id)) continue; // local edit wins
          final existing = byId[remote.id];
          if (existing == null ||
              remote.updatedAt.isAfter(existing.updatedAt)) {
            await _local.upsert(remote, synced: true);
          }
        } catch (_) {
          // Skip malformed documents.
        }
      }
    } catch (_) {
      // Offline: fall through to whatever is local.
    }
    return getLocations(userId);
  }
}
