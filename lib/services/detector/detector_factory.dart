import 'package:flutter/foundation.dart';

import 'mock_detector.dart';
import 'money_detector.dart';

/// The ONE place that decides which detector the app uses.
///
/// When your YOLO26 model is ready (Part 22), `create()` will return the
/// real detector first. Nothing else in the app has to change.
class DetectorFactory {
  DetectorFactory._();

  /// Which invented scene the fake detector shows (set from the dev tools).
  static MockScenario mockScenario = MockScenario.normal;

  static const bool _allowDemoFlag = bool.fromEnvironment('ALLOW_DEMO');

  /// Fake detections are allowed while you develop (debug builds) and in
  /// builds made with  --dart-define=ALLOW_DEMO=true  (for presentations).
  /// A normal release build NEVER shows invented results.
  static bool get demoAllowed => kDebugMode || _allowDemoFlag;

  static MoneyDetector create({bool? allowDemo}) {
    if (allowDemo ?? demoAllowed) return MockDetector(scenario: mockScenario);
    return const UnavailableDetector();
  }
}
