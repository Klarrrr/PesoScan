import 'dart:ui' show Rect;

import '../models/detection.dart';
import '../models/money_class.dart';
import '../models/scan_record.dart';

/// Fake scans so you can see the Home design before real saving exists.
/// Totals are CALCULATED from the coins, never typed by hand.
List<ScanRecord> sampleScans({DateTime? now}) {
  final base = now ?? DateTime.now();

  ScanRecord make(String id, Duration ago, List<int> classIds) {
    return ScanRecord(
      id: id,
      createdAt: base.subtract(ago),
      imagePath: '',
      detections: [
        for (final classId in classIds)
          Detection(
            money: MoneyClasses.byId(classId),
            confidence: 0.9,
            box: const Rect.fromLTWH(0.1, 0.1, 0.1, 0.1),
          ),
      ],
    );
  }

  return [
    make('sample-1', const Duration(minutes: 20), [7, 7, 6, 5, 3, 4, 1]),
    make('sample-2', const Duration(minutes: 55), [7, 7, 6, 5, 3, 4]),
    make('sample-3', const Duration(hours: 3), [14, 12, 11]),
    make('sample-4', const Duration(days: 1, hours: 2), [15, 12, 7, 7]),
  ];
}
