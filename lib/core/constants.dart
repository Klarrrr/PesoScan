/// App-wide constants. Keep "magic numbers" here so we can change them in one place.
class AppConstants {
  AppConstants._(); // private constructor: this class is never instantiated

  /// Detections below this confidence (0.0 to 1.0) are flagged as "low confidence".
  static const double lowConfidenceThreshold = 0.60;
}
