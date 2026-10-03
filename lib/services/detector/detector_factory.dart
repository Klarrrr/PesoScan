import 'mock_detector.dart';
import 'money_detector.dart';

/// The ONE place that decides which detector the app uses.
/// Part 22: this will create the real YoloDetector when the model is present.
class DetectorFactory {
  DetectorFactory._();

  /// Which invented scene the fake detector shows (set from the dev tools).
  static MockScenario mockScenario = MockScenario.normal;

  static MoneyDetector create() => MockDetector(scenario: mockScenario);
}
