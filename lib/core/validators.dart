/// Form rules. Each returns null when the value is OK,
/// or the message to show under the field.
class Validators {
  Validators._();

  static String? username(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Choose a username';
    if (v.length < 3 || v.length > 20) return 'Use 3 to 20 characters';
    if (!RegExp(r'^[A-Za-z0-9_]+$').hasMatch(v)) {
      return 'Letters, numbers and underscores only';
    }
    return null;
  }

  static String? email(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Enter your email';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  /// Login: we only check that something was typed.
  static String? passwordRequired(String? value) =>
      (value ?? '').isEmpty ? 'Enter your password' : null;

  /// Register / reset: the rules for a NEW password.
  static String? newPassword(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Choose a password';
    if (v.length < 8) return 'Use at least 8 characters';
    if (!RegExp(r'[A-Za-z]').hasMatch(v) || !RegExp(r'\d').hasMatch(v)) {
      return 'Include letters and numbers';
    }
    return null;
  }

  static String? confirmPassword(String? value, String original) {
    if ((value ?? '').isEmpty) return 'Confirm your password';
    return value != original ? 'Passwords do not match' : null;
  }

  static String? code(String? value) =>
      RegExp(r'^\d{6}$').hasMatch((value ?? '').trim())
      ? null
      : 'Enter the 6-digit code';
}
