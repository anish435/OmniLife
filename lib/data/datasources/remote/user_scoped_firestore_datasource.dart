import 'package:cloud_firestore/cloud_firestore.dart';

import 'firestore_paths.dart';

/// Generic CRUD foundation for any `users/{uid}/{collection}/{docId}`
/// subcollection described in docs/architecture.md.
///
/// This is intentionally generic (`Map<String, dynamic>` in/out) — it is
/// the Firebase foundation only. Per-feature repositories (Task, Note,
/// Habit, etc.) will wrap this with typed models in a later phase.
class UserScopedFirestoreDataSource {
  UserScopedFirestoreDataSource({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _collection(
    String uid,
    String collection,
  ) {
    return _firestore.collection(userScopedCollectionPath(uid, collection));
  }

  Future<List<Map<String, dynamic>>> list(String uid, String collection) async {
    final snapshot = await _collection(uid, collection).get();
    return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
  }

  Future<Map<String, dynamic>?> get(
    String uid,
    String collection,
    String docId,
  ) async {
    final doc = await _collection(uid, collection).doc(docId).get();
    if (!doc.exists) return null;
    return {'id': doc.id, ...?doc.data()};
  }

  Future<String> create(
    String uid,
    String collection,
    Map<String, dynamic> data,
  ) async {
    final ref = await _collection(uid, collection).add(data);
    return ref.id;
  }

  Future<void> set(
    String uid,
    String collection,
    String docId,
    Map<String, dynamic> data,
  ) {
    return _collection(uid, collection)
        .doc(docId)
        .set(data, SetOptions(merge: true));
  }

  Future<void> update(
    String uid,
    String collection,
    String docId,
    Map<String, dynamic> data,
  ) {
    return _collection(uid, collection).doc(docId).update(data);
  }

  Future<void> delete(String uid, String collection, String docId) {
    return _collection(uid, collection).doc(docId).delete();
  }
}
