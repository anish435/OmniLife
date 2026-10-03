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
    try {
      final snapshot = await _collection(uid, collection)
          .get()
          .timeout(const Duration(milliseconds: 1500));
      return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> get(
    String uid,
    String collection,
    String docId,
  ) async {
    try {
      final doc = await _collection(uid, collection)
          .doc(docId)
          .get()
          .timeout(const Duration(milliseconds: 1500));
      if (!doc.exists) return null;
      return {'id': doc.id, ...?doc.data()};
    } catch (_) {
      return null;
    }
  }

  Future<String> create(
    String uid,
    String collection,
    Map<String, dynamic> data,
  ) async {
    final ref = await _collection(uid, collection)
        .add(data)
        .timeout(const Duration(milliseconds: 1500));
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
        .set(data, SetOptions(merge: true))
        .timeout(const Duration(milliseconds: 1500));
  }

  Future<void> update(
    String uid,
    String collection,
    String docId,
    Map<String, dynamic> data,
  ) {
    return _collection(uid, collection)
        .doc(docId)
        .update(data)
        .timeout(const Duration(milliseconds: 1500));
  }

  Future<void> delete(String uid, String collection, String docId) {
    return _collection(uid, collection)
        .doc(docId)
        .delete()
        .timeout(const Duration(milliseconds: 1500));
  }
}
