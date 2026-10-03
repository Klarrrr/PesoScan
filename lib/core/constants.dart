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

  // ---- Camera assistance (Part 17) ----
  // These are first guesses. Tune them by testing on a real phone.

  /// Average picture brightness: 0 = black, 255 = white.
  static const double tooDarkBelow = 55;
  static const double tooBrightAbove = 220;

  /// Average change between two looks at the picture (0 = perfectly still).
  static const double shakyAbove = 16;

  /// A gap smaller than this share of an item's size counts as "too close".
  static const double minGapShare = 0.15;

  /// How often the picture is checked for light and shaking.
  static const Duration analysisInterval = Duration(milliseconds: 250);

  static const String suggestedDistance = '20-30 cm';
}
