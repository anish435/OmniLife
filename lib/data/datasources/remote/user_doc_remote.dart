import 'user_scoped_firestore_datasource.dart';

/// Minimal remote document store for `users/{uid}/{collection}/{docId}`.
///
/// Exists so repositories can be tested with an in-memory fake instead of
/// Firestore. [set] must be idempotent (merge semantics).
abstract class UserDocRemote {
  Future<void> set(
    String uid,
    String collection,
    String docId,
    Map<String, dynamic> data,
  );

  Future<void> delete(String uid, String collection, String docId);

  Future<List<Map<String, dynamic>>> list(String uid, String collection);
}

/// [UserDocRemote] backed by the shared [UserScopedFirestoreDataSource]
/// (`set` there is `SetOptions(merge: true)`).
class FirestoreUserDocRemote implements UserDocRemote {
  FirestoreUserDocRemote([UserScopedFirestoreDataSource? source])
    : _source = source ?? UserScopedFirestoreDataSource();

  final UserScopedFirestoreDataSource _source;

  @override
  Future<void> set(
    String uid,
    String collection,
    String docId,
    Map<String, dynamic> data,
  ) => _source.set(uid, collection, docId, data);

  @override
  Future<void> delete(String uid, String collection, String docId) =>
      _source.delete(uid, collection, docId);

  @override
  Future<List<Map<String, dynamic>>> list(String uid, String collection) =>
      _source.list(uid, collection);
}
