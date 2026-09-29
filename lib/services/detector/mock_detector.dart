import 'dart:math';
import 'dart:ui' show Rect;

import '../../models/detection.dart';
import '../../models/money_class.dart';
import 'money_detector.dart';

/// A fake detector for development. Each "scene" is either 3-5 coins or
/// 2-3 bills, with slight box jitter and confidence flicker every frame,
/// like a real model would produce. Some items get low confidence on
/// purpose, so we can test the warning UI.
class MockDetector implements MoneyDetector {
  final Random _rng;
  List<_MockItem> _items = [];

  /// Pass a `seed` to get the same scene every run (useful in tests).
  MockDetector({int? seed}) : _rng = Random(seed);

  // Preset coin positions (center x, center y) that don't overlap.
  static const List<(double, double)> _coinSlots = [
    (0.25, 0.28),
    (0.72, 0.28),
    (0.25, 0.68),
    (0.72, 0.68),
    (0.48, 0.48),
  ];

  // Bills are wide rectangles stacked in rows (center y).
  static const List<double> _billRows = [0.2, 0.5, 0.8];

  @override
  Future<void> initialize() async => regenerate();

  /// Create a brand-new random scene (coins or bills).
  /// Only the mock has this; the real detector does not.
  void regenerate() {
    _items = _rng.nextBool() ? _coinScene() : _billScene();
  }

  List<_MockItem> _coinScene() {
    final slots = [..._coinSlots]..shuffle(_rng);
    final count = 3 + _rng.nextInt(3); // 3, 4 or 5 coins
    return List.generate(count, (i) {
      final size = 0.14 + _rng.nextDouble() * 0.06;
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
