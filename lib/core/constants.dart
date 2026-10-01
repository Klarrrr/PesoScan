/// App-wide constants. Keep "magic numbers" here so we can change them in one place.
class AppConstants {
  AppConstants._(); // private constructor: this class is never instantiated

  static const String appName = 'PesoScan';

  /// How long the splash screen stays visible.
  static const Duration splashDuration = Duration(milliseconds: 2200);

  /// Confidence (0.0 to 1.0) at or above this = green label.
  static const double highConfidenceThreshold = 0.80;

  /// Below this = red label and "low confidence" warnings.
  static const double lowConfidenceThreshold = 0.60;

  /// How often the detector may run (about 10 times per second).
  static const Duration detectionInterval = Duration(milliseconds: 100);
}
