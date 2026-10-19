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
    : _injectedFirestore = firestore;

  final FirebaseFirestore? _injectedFirestore;

  // The first read after opening a screen on web can take several seconds.
  // A short timeout used to hand back an empty list that looked real.
  static const _timeout = Duration(seconds: 12);

  FirebaseFirestore? get _firestore {
    if (_injectedFirestore != null) return _injectedFirestore;
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  CollectionReference<Map<String, dynamic>>? _collection(
    String uid,
    String collection,
  ) {
    final firestore = _firestore;
    if (firestore == null) return null;
    return firestore.collection(userScopedCollectionPath(uid, collection));
  }

  Future<List<Map<String, dynamic>>> list(String uid, String collection) async {
    try {
      final col = _collection(uid, collection);
      if (col == null) return [];
      final snapshot = await col.get().timeout(_timeout);
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
      final col = _collection(uid, collection);
      if (col == null) return null;
      final doc = await col.doc(docId).get().timeout(_timeout);
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
    final col = _collection(uid, collection);
    if (col == null) return '';
    final ref = await col.add(data).timeout(_timeout);
    return ref.id;
  }

  Future<void> set(
    String uid,
    String collection,
    String docId,
    Map<String, dynamic> data,
  ) {
    final col = _collection(uid, collection);
    if (col == null) return Future.value();
    return col.doc(docId).set(data, SetOptions(merge: true)).timeout(_timeout);
  }

  Future<void> update(
    String uid,
    String collection,
    String docId,
    Map<String, dynamic> data,
  ) {
    final col = _collection(uid, collection);
    if (col == null) return Future.value();
    return col.doc(docId).update(data).timeout(_timeout);
  }

  Future<void> delete(String uid, String collection, String docId) {
    final col = _collection(uid, collection);
    if (col == null) return Future.value();
    return col.doc(docId).delete().timeout(_timeout);
  }
}
