import 'package:shared_preferences/shared_preferences.dart';

/// Remembers, on this phone, that the user agreed to the Terms of Service
/// and the Privacy Policy.
class TermsConsent {
  TermsConsent._();

  static const storageKey = 'terms_accepted_version';

  /// Raise this number when the Terms or the Privacy Policy change in a way
  /// people must agree to again.
  static const currentVersion = 1;

  static Future<bool> isAccepted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(storageKey) == currentVersion;
    } catch (_) {
      return false; // storage not available: just ask again
    }
  }

  static Future<void> accept() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(storageKey, currentVersion);
    } catch (_) {
      // Nothing useful to do if saving fails.
    }
  }
}
