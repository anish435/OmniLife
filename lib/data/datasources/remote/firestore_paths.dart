/// Names of the user-owned subcollections under `users/{uid}`, as
/// documented in docs/architecture.md §5 (Firestore ownership model).
///
/// Centralizing these avoids typo'd collection names being scattered
/// across future per-feature repositories.
abstract final class FirestoreCollections {
  static const users = 'users';
  static const tasks = 'tasks';
  static const projects = 'projects';
  static const events = 'events';
  static const notes = 'notes';
  static const habits = 'habits';
  static const goals = 'goals';
  static const expenses = 'expenses';
  static const wellness = 'wellness';
  static const conversations = 'conversations';
}

/// Builds the Firestore path for a user-owned subcollection, e.g.
/// `users/{uid}/tasks`.
String userScopedCollectionPath(String uid, String collection) =>
    '${FirestoreCollections.users}/$uid/$collection';
