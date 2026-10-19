import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/reminder_model.dart';
import 'firestore_paths.dart';

/// Firestore collection name for reminders (`users/{uid}/reminders`).
const remindersCollection = 'reminders';

/// Reads reminders from Firestore. Writes go through the sync engine.
abstract class ReminderRemoteDataSource {
  Future<List<ReminderModel>> list(String uid);
}

class FirestoreReminderRemoteDataSource implements ReminderRemoteDataSource {
  FirestoreReminderRemoteDataSource({this.firestore});

  final FirebaseFirestore? firestore;

  @override
  Future<List<ReminderModel>> list(String uid) async {
    final db = firestore ?? FirebaseFirestore.instance;
    final snap = await db
        .collection(userScopedCollectionPath(uid, remindersCollection))
        .get()
        .timeout(const Duration(seconds: 10));
    return [
      for (final d in snap.docs) ReminderModel.fromFirestoreMap(d.id, d.data()),
    ];
  }
}
