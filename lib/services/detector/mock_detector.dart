import 'dart:math';
import 'dart:ui' show Rect;

import '../../models/detection.dart';
import '../../models/money_class.dart';
import 'money_detector.dart';

/// Which kind of scene the fake detector invents.
/// "crowded" and "edge" exist to test the camera-assistance warnings.
enum MockScenario { normal, crowded, edge }

/// A fake detector for development. It "sees" a few coins or bills with
/// slight box jitter and confidence flicker every frame, like a real model.
class MockDetector implements MoneyDetector {
  final Random _rng;
  MockScenario scenario;
  List<_MockItem> _items = [];

  /// Pass a `seed` to get the same scene every run (useful in tests).
  MockDetector({int? seed, this.scenario = MockScenario.normal})
    : _rng = Random(seed);

  // Preset coin positions (centre x, centre y) that keep a healthy gap.
  static const List<(double, double)> _coinSlots = [
    (0.25, 0.28),
    (0.72, 0.28),
    (0.25, 0.68),
    (0.72, 0.68),
    (0.50, 0.48),
  ];

  // Bills are wide rectangles stacked in rows (centre y).
  static const List<double> _billRows = [0.2, 0.5, 0.8];

  @override
  Future<void> initialize() async => regenerate();

  /// Create a brand-new scene.
  /// Only the mock has this; the real detector does not.
  void regenerate() {
    _items = switch (scenario) {
      MockScenario.normal => _rng.nextBool() ? _coinScene() : _billScene(),
      MockScenario.crowded => _crowdedScene(),
      MockScenario.edge => _edgeScene(),
    };
  }

  List<_MockItem> _coinScene() {
    final slots = [..._coinSlots]..shuffle(_rng);
    final count = 3 + _rng.nextInt(3); // 3, 4 or 5 coins
    return List.generate(count, (i) {
      final size = 0.12 + _rng.nextDouble() * 0.05;
      return _MockItem(
        money: _pick(MoneyClasses.coins),
        cx: slots[i].$1,
        cy: slots[i].$2,
        w: size,
        h: size,
        baseConfidence: _randomConfidence(),
      );
    });
  }

  List<_MockItem> _billScene() {
    final count = 2 + _rng.nextInt(2); // 2 or 3 bills
    return List.generate(count, (i) {
      return _MockItem(
        money: _pick(MoneyClasses.bills),
        cx: 0.5,
        cy: _billRows[i],
        w: 0.70,
        h: 0.20,
        baseConfidence: _randomConfidence(),
      );
    });
  }

  /// Two coins overlapping and a third close by: "too close together".
  List<_MockItem> _crowdedScene() => [
    _item(MoneyClasses.coins, 0.40, 0.45, 0.16),
    _item(MoneyClasses.coins, 0.50, 0.47, 0.16),
    _item(MoneyClasses.coins, 0.70, 0.62, 0.16),
  ];

  /// One coin sticking out of the right edge, one touching the left edge.
  List<_MockItem> _edgeScene() => [
    _item(MoneyClasses.coins, 0.93, 0.40, 0.16),
    _item(MoneyClasses.coins, 0.08, 0.70, 0.16),
    _item(MoneyClasses.coins, 0.50, 0.50, 0.16),
  ];

  _MockItem _item(List<MoneyClass> pool, double cx, double cy, double size) =>
      _MockItem(
        money: _pick(pool),
        cx: cx,
        cy: cy,
        w: size,
        h: size,
        baseConfidence: _randomConfidence(),
      );

  MoneyClass _pick(List<MoneyClass> pool) => pool[_rng.nextInt(pool.length)];

  double _randomConfidence() => 0.50 + _rng.nextDouble() * 0.45; // 0.50-0.95

  @override
  Future<List<Detection>> detect(DetectorFrame frame) async {
    // Pretend the neural network takes a little time.
    await Future<void>.delayed(const Duration(milliseconds: 30));

    return _items.map((item) {
      final dx = (_rng.nextDouble() - 0.5) * 0.008; // tiny jitter
      final dy = (_rng.nextDouble() - 0.5) * 0.008;
      final conf = (item.baseConfidence + (_rng.nextDouble() - 0.5) * 0.06)
          .clamp(0.0, 0.99);
      return Detection(
        money: item.money,
        confidence: conf,
        box: Rect.fromLTRB(
          item.cx + dx - item.w / 2,
          item.cy + dy - item.h / 2,
          item.cx + dx + item.w / 2,
          item.cy + dy + item.h / 2,
        ),
      );
    }).toList();
  }

  @override
  void dispose() {}
}

class _MockItem {
  final MoneyClass money;
  final double cx, cy, w, h, baseConfidence;
  const _MockItem({
    required this.money,
    required this.cx,
    required this.cy,
    required this.w,
    required this.h,
    required this.baseConfidence,
  });
}
