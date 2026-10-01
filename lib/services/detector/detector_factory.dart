import 'mock_detector.dart';
import 'money_detector.dart';

/// The ONE place that decides which detector the app uses.
/// Part 22: change the line below to `YoloDetector()`.
class DetectorFactory {
  DetectorFactory._();

  static MoneyDetector create() => MockDetector();
}
