import 'dart:convert';

enum SyncOpType { set, delete }

enum SyncOpState { pending, failed }

/// One queued remote write. The id is `collection/docId`, so queuing a
/// second write to the same document replaces the first (the newest local
/// state is what should reach the server) and replaying an operation is
/// idempotent: a `set` of a fixed doc id with the same payload.
class SyncOperation {
  const SyncOperation({
    required this.uid,
    required this.collection,
    required this.docId,
    required this.type,
    required this.updatedAtMs,
    required this.createdAtMs,
    this.data,
    this.attempts = 0,
    this.nextAttemptAtMs = 0,
    this.lastError,
    this.state = SyncOpState.pending,
  });

  final String uid;
  final String collection;
  final String docId;
  final SyncOpType type;

  /// Logical time of the local change, used for last-writer-wins
  /// conflict resolution against the server copy.
  final int updatedAtMs;
  final int createdAtMs;
  final Map<String, dynamic>? data;
  final int attempts;
  final int nextAttemptAtMs;
  final String? lastError;
  final SyncOpState state;

  String get id => '$collection/$docId';

  SyncOperation copyWith({
    int? attempts,
    int? nextAttemptAtMs,
    String? lastError,
    bool clearError = false,
    SyncOpState? state,
  }) {
    return SyncOperation(
      uid: uid,
      collection: collection,
      docId: docId,
      type: type,
      updatedAtMs: updatedAtMs,
      createdAtMs: createdAtMs,
      data: data,
      attempts: attempts ?? this.attempts,
      nextAttemptAtMs: nextAttemptAtMs ?? this.nextAttemptAtMs,
      lastError: clearError ? null : (lastError ?? this.lastError),
      state: state ?? this.state,
    );
  }

  Map<String, Object?> toMap() => {
    'id': id,
    'uid': uid,
    'collection': collection,
    'doc_id': docId,
    'type': type.name,
    'data': data == null ? null : jsonEncode(data),
    'updated_at': updatedAtMs,
    'created_at': createdAtMs,
    'attempts': attempts,
    'next_attempt_at': nextAttemptAtMs,
    'last_error': lastError,
    'state': state.name,
  };

  factory SyncOperation.fromMap(Map<String, Object?> map) {
    final raw = map['data'] as String?;
    return SyncOperation(
      uid: map['uid']! as String,
      collection: map['collection']! as String,
      docId: map['doc_id']! as String,
      type: SyncOpType.values.byName(map['type']! as String),
      data: raw == null ? null : jsonDecode(raw) as Map<String, dynamic>,
      updatedAtMs: (map['updated_at']! as num).toInt(),
      createdAtMs: (map['created_at']! as num).toInt(),
      attempts: (map['attempts']! as num).toInt(),
      nextAttemptAtMs: (map['next_attempt_at']! as num).toInt(),
      lastError: map['last_error'] as String?,
      state: SyncOpState.values.byName(map['state']! as String),
    );
  }
}
