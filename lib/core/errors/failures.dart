/// Base type for domain-level failures surfaced from the data layer.
///
/// UI/state-management code should depend on [Failure], never on
/// Firebase-specific exception types directly.
abstract class Failure {
  const Failure(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthFailure extends Failure {
  const AuthFailure(super.message, {this.code});

  final String? code;
}

class FirestoreFailure extends Failure {
  const FirestoreFailure(super.message, {this.code});

  final String? code;
}

class UnknownFailure extends Failure {
  const UnknownFailure(super.message);
}
