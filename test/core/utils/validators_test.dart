import 'package:flutter_test/flutter_test.dart';
import 'package:omnilife/core/utils/validators.dart';

void main() {
  group('Validators.email', () {
    test('rejects empty input', () {
      expect(Validators.email(''), isNotNull);
      expect(Validators.email(null), isNotNull);
    });

    test('rejects malformed email', () {
      expect(Validators.email('not-an-email'), isNotNull);
      expect(Validators.email('missing@domain'), isNotNull);
    });

    test('accepts a valid email', () {
      expect(Validators.email('user@example.com'), isNull);
    });
  });

  group('Validators.password', () {
    test('rejects empty input', () {
      expect(Validators.password(''), isNotNull);
    });

    test('rejects passwords shorter than 8 characters', () {
      expect(Validators.password('short1'), isNotNull);
    });

    test('accepts a reasonable password', () {
      expect(Validators.password('longenough1'), isNull);
    });
  });

  group('Validators.confirmPassword', () {
    test('rejects empty input', () {
      expect(Validators.confirmPassword('', 'password123'), isNotNull);
    });

    test('rejects mismatched passwords', () {
      expect(
        Validators.confirmPassword('different1', 'password123'),
        isNotNull,
      );
    });

    test('accepts a matching confirmation', () {
      expect(Validators.confirmPassword('password123', 'password123'), isNull);
    });
  });
}
