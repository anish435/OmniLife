/// One thing the user told the assistant that was recorded, kept in a
/// structured form so the advice can use the real numbers.
enum LoggedKind { sleep, water, meal, workout, mood, energy, focus }

class LoggedFact {
  const LoggedFact(this.kind, {this.value, this.at});

  final LoggedKind kind;

  /// sleep: minutes slept. water: ml. workout/focus: minutes.
  /// mood/energy: 1-5. meal: unused.
  final int? value;

  /// When the moment happened (local), if known.
  final DateTime? at;

  @override
  String toString() => 'LoggedFact(${kind.name}, $value)';
}
