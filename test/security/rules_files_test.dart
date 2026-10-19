import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:omnilife/data/datasources/remote/firestore_paths.dart';
import 'package:omnilife/data/datasources/remote/life_event_remote_data_source.dart';

/// Static guard for the rules files. It cannot evaluate the rules (that
/// needs the Firebase emulator, see docs/security.md); it catches the usual
/// accidents: a new collection nobody added, a rule opened up, or the
/// default deny going missing.
void main() {
  final firestore = File('firestore.rules').readAsStringSync();
  final storage = File('storage.rules').readAsStringSync();

  test('every collection the app uses is named in firestore.rules', () {
    const used = [
      FirestoreCollections.tasks,
      FirestoreCollections.projects,
      FirestoreCollections.events,
      FirestoreCollections.notes,
      FirestoreCollections.habits,
      FirestoreCollections.goals,
      FirestoreCollections.expenses,
      FirestoreCollections.wellness,
      FirestoreCollections.conversations,
      FirestoreCollections.devices,
      FirestoreCollections.focusSessions,
      lifeEventsCollection,
      'habit_logs',
      'locations',
      'sensor_daily',
      'reminders',
      'settings',
    ];
    for (final name in used) {
      expect(
        firestore.contains("'$name'") || firestore.contains('/$name/'),
        isTrue,
        reason: '$name is missing from firestore.rules',
      );
    }
  });

  test('firestore.rules never grants access unconditionally', () {
    expect(firestore, isNot(contains('if true')));
    expect(firestore, contains('request.auth.uid == uid'));
  });

  test('firestore.rules ends with a default deny', () {
    final catchAll = firestore.lastIndexOf('match /{document=**}');
    expect(catchAll, greaterThan(0));
    expect(
      firestore.substring(catchAll),
      contains('allow read, write: if false'),
    );
  });

  test('life events are type checked', () {
    expect(firestore, contains('request.resource.data.timestamp is int'));
  });

  test('storage.rules isolates receipts per user and denies the rest', () {
    expect(storage, contains('match /receipts/{uid}/{fileName}'));
    expect(storage, contains('request.auth.uid == uid'));
    expect(storage, contains('request.resource.size <'));
    expect(storage, isNot(contains('if true')));
    final catchAll = storage.lastIndexOf('match /{allPaths=**}');
    expect(catchAll, greaterThan(0));
    expect(
      storage.substring(catchAll),
      contains('allow read, write: if false'),
    );
  });
}
