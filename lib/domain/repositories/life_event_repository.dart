import '../entities/life_event.dart';

/// Stores OmniPulse life events. Recording is local-first and instant;
/// cloud sync happens in the background and never blocks the caller.
abstract class LifeEventRepository {
  /// Records an event now (or at [at]); never requires any detail.
  Future<LifeEvent> record(
    String uid,
    LifeEventType type, {
    DateTime? at,
    Map<String, dynamic> metadata = const {},
  });

  /// Edits an event (e.g. correcting a late tap's time).
  Future<LifeEvent> update(LifeEvent event);

  Future<void> delete(LifeEvent event);

  /// Events with `from <= timestamp < to`, oldest first.
  Future<List<LifeEvent>> range(String uid, DateTime from, DateTime to);

  /// Pulls remote changes into local storage (mobile). Safe to call often;
  /// failures are swallowed because local data is authoritative offline.
  Future<void> refreshFromRemote(String uid, {int days = 90});

  /// Emits whenever local data changed (writes or remote merges) so
  /// views can reload.
  Stream<void> get changes;
}
