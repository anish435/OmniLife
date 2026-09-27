/// Pure form-field validators, shared by every auth (and future) form.
/// Framework-agnostic: no Flutter/Firebase imports, easy to unit test.
abstract final class Validators {
  static final _emailPattern = RegExp(r'^[\w.+-]+@[\w-]+\.[\w-]+(\.[\w-]+)*$');

  static String? required(String? value, {String fieldName = 'This field'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  static String? email(String? value) {
    final requiredError = required(value, fieldName: 'Email');
    if (requiredError != null) return requiredError;
    if (!_emailPattern.hasMatch(value!.trim())) {
      return 'Enter a valid email address';
    }
    return null;
  }

  static String? password(String? value) {
    final requiredError = required(value, fieldName: 'Password');
    if (requiredError != null) return requiredError;
    if (value!.length < 8) {
      return 'Password must be at least 8 characters';
    }
    return null;
  }

  static String? confirmPassword(String? value, String password) {
    final requiredError = required(value, fieldName: 'Confirm password');
    if (requiredError != null) return requiredError;
    if (value != password) {
      return 'Passwords do not match';
    }
    return null;
  }
}
