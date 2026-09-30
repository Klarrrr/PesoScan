/// App-wide constants. Keep "magic numbers" here so we can change them in one place.
class AppConstants {
  AppConstants._(); // private constructor: this class is never instantiated

  static const String appName = 'PesoScan';

  /// How long the splash screen stays visible.
  static const Duration splashDuration = Duration(milliseconds: 2200);

  /// Detections below this confidence (0.0 to 1.0) are flagged as "low confidence".
  static const double lowConfidenceThreshold = 0.60;
}
