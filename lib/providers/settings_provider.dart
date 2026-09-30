import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide user preferences, saved on the phone so they survive restarts.
/// ChangeNotifier = when a value changes we call notifyListeners(), and
/// every widget watching this provider rebuilds automatically.
class SettingsProvider extends ChangeNotifier {
  static const _kTheme = 'theme_mode';
  static const _kHaptic = 'haptic_enabled';
  static const _kAudio = 'audio_enabled';
  static const _kOnboarding = 'onboarding_done';

  late SharedPreferences _prefs;

  // The prototype's default theme is Dark.
  ThemeMode _themeMode = ThemeMode.dark;
  bool _hapticEnabled = true;
  bool _audioEnabled = true;
  bool _onboardingDone = false;

  ThemeMode get themeMode => _themeMode;
  bool get hapticEnabled => _hapticEnabled;
  bool get audioEnabled => _audioEnabled;
  bool get onboardingDone => _onboardingDone;

  /// Call once at startup, before runApp().
  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();

    final themeName = _prefs.getString(_kTheme);
    _themeMode = ThemeMode.values.firstWhere(
      (m) => m.name == themeName,
      orElse: () => ThemeMode.dark,
    );
    _hapticEnabled = _prefs.getBool(_kHaptic) ?? true;
    _audioEnabled = _prefs.getBool(_kAudio) ?? true;
    _onboardingDone = _prefs.getBool(_kOnboarding) ?? false;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    await _prefs.setString(_kTheme, mode.name);
  }

  Future<void> setHapticEnabled(bool value) async {
    _hapticEnabled = value;
    notifyListeners();
    await _prefs.setBool(_kHaptic, value);
  }

  Future<void> setAudioEnabled(bool value) async {
    _audioEnabled = value;
    notifyListeners();
    await _prefs.setBool(_kAudio, value);
  }

  Future<void> setOnboardingDone(bool value) async {
    _onboardingDone = value;
    notifyListeners();
    await _prefs.setBool(_kOnboarding, value);
  }
}
