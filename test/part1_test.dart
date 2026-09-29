import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:pesoscan/core/money.dart';
import 'package:pesoscan/core/scan_math.dart';
import 'package:pesoscan/models/detection.dart';
import 'package:pesoscan/models/money_class.dart';
import 'package:pesoscan/services/detector/mock_detector.dart';
import 'package:pesoscan/services/detector/money_detector.dart';

Detection det(MoneyClass m, {double conf = 0.9}) => Detection(
  money: m,
  confidence: conf,
  box: const Rect.fromLTWH(0.1, 0.1, 0.1, 0.1),
);

void main() {
  group('money formatting', () {
    test('formatPeso', () {
      expect(formatPeso(4625), '₱46.25');
      expect(formatPeso(0), '₱0.00');
      expect(formatPeso(123456), '₱1,234.56');
    });

    test('formatPesoShort', () {
      expect(formatPesoShort(500), '₱5');
      expect(formatPesoShort(5), '₱0.05');
      expect(formatPesoShort(10), '₱0.10');
      expect(formatPesoShort(100000), '₱1000');
    });
  });

  group('money classes', () {
    test('ids run 1 to 19 with no gaps or duplicates', () {
      final ids = MoneyClasses.all.map((c) => c.id).toList();
      expect(ids, List.generate(19, (i) => i + 1));
    });

    test('yoloIndex starts at 0', () {
      expect(MoneyClasses.byId(1).yoloIndex, 0);
      expect(MoneyClasses.byId(19).yoloIndex, 18);
    });

    test('coins and bills are split correctly', () {
      expect(MoneyClasses.coins.length, 9);
      expect(MoneyClasses.bills.length, 10);
    });
  });

  group('scan math', () {
    test('2x P10 BSP + 1x P5 NGC + 1x P0.05 = P25.05', () {
      final list = [
        det(MoneyClasses.byId(7)),
        det(MoneyClasses.byId(7)),
        det(MoneyClasses.byId(6)),
        det(MoneyClasses.byId(1)),
      ];
      expect(totalCentavos(list), 2505);
      expect(formatPeso(totalCentavos(list)), '₱25.05');
    });

    test('mixed coins and bills', () {
      final list = [
        det(MoneyClasses.byId(12)), // P100 NGC bill
        det(MoneyClasses.byId(17)), // P100 Polymer bill
        det(MoneyClasses.byId(8)), // P10 NGC coin
      ];
      expect(totalCentavos(list), 21000);
      expect(countOfType(list, MoneyType.bill), 2);
      expect(countOfType(list, MoneyType.coin), 1);
    });

    test('countByClass groups and sorts high to low', () {
      final list = [
        det(MoneyClasses.byId(1)),
        det(MoneyClasses.byId(7)),
        det(MoneyClasses.byId(7)),
      ];
      final counts = countByClass(list);
      expect(counts.keys.first, MoneyClasses.byId(7));
      expect(counts[MoneyClasses.byId(7)], 2);
    });
  });

  group('detection', () {
    test('low confidence flag', () {
      expect(det(MoneyClasses.byId(3), conf: 0.5).isLowConfidence, isTrue);
      expect(det(MoneyClasses.byId(3), conf: 0.9).isLowConfidence, isFalse);
    });
  });

  group('MockDetector', () {
    test('returns valid detections in many scenes', () async {
      final detector = MockDetector(seed: 1);
      await detector.initialize();

      // Try several random scenes (coins and bills).
      for (var i = 0; i < 10; i++) {
        detector.regenerate();
        final results = await detector.detect(
          const DetectorFrame(width: 1080, height: 1920),
        );

        expect(results.length, inInclusiveRange(2, 5));
        for (final d in results) {
          expect(d.confidence, inInclusiveRange(0.0, 1.0));
          expect(d.box.left, greaterThanOrEqualTo(0));
          expect(d.box.right, lessThanOrEqualTo(1));
          expect(d.box.top, greaterThanOrEqualTo(0));
          expect(d.box.bottom, lessThanOrEqualTo(1));
        }
      }
    });
  });
}
