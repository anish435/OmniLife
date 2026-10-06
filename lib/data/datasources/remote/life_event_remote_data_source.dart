import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/life_event_model.dart';
import 'firestore_paths.dart';

/// Firestore collection name for OmniPulse events.
const lifeEventsCollection = 'life_events';

/// Reads OmniPulse events from `users/{uid}/life_events`. Writes go through
/// the sync engine, never directly from here.
abstract class LifeEventRemoteDataSource {
  /// Documents (including tombstones) with `from <= timestamp < to`.
  Future<List<LifeEventModel>> range(String uid, DateTime from, DateTime to);
}

class FirestoreLifeEventRemoteDataSource implements LifeEventRemoteDataSource {
  FirestoreLifeEventRemoteDataSource({this.firestore});

  final FirebaseFirestore? firestore;

  @override
  Future<List<LifeEventModel>> range(
    String uid,
    DateTime from,
    DateTime to,
  ) async {
    final db = firestore ?? FirebaseFirestore.instance;
    final snap = await db
        .collection(userScopedCollectionPath(uid, lifeEventsCollection))
        .where('timestamp', isGreaterThanOrEqualTo: from.millisecondsSinceEpoch)
        .where('timestamp', isLessThan: to.millisecondsSinceEpoch)
        .get()
        .timeout(const Duration(seconds: 10));
    return [
      for (final d in snap.docs)
        LifeEventModel.fromFirestoreMap(d.id, d.data()),
    ];
  }
}
