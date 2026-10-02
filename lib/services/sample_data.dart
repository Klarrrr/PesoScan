import 'dart:ui' show Rect;

import 'package:uuid/uuid.dart';

import '../models/detection.dart';
import '../models/money_class.dart';
import '../models/scan_record.dart';

ScanRecord _make({
  required String id,
  required DateTime createdAt,
  required List<int> classIds,
  String? userId,
  double confidence = 0.9,
}) {
  return ScanRecord(
    id: id,
    userId: userId,
    createdAt: createdAt,
    imagePath: '',
    detections: [
      for (final classId in classIds)
        Detection(
          money: MoneyClasses.byId(classId),
          confidence: confidence,
          box: const Rect.fromLTWH(0.1, 0.1, 0.1, 0.1),
        ),
    ],
  );
}

/// 4 fake scans (used by the Home tests). Totals are CALCULATED, never typed.
List<ScanRecord> sampleScans({DateTime? now, String? userId}) {
  final base = now ?? DateTime.now();
  ScanRecord make(String id, Duration ago, List<int> ids) => _make(
    id: id,
    createdAt: base.subtract(ago),
    classIds: ids,
    userId: userId,
  );

  return [
    make('sample-1', const Duration(minutes: 20), [7, 7, 6, 5, 3, 4, 1]),
    make('sample-2', const Duration(minutes: 55), [7, 7, 6, 5, 3, 4]),
    make('sample-3', const Duration(hours: 3), [14, 12, 11]),
    make('sample-4', const Duration(days: 1, hours: 2), [15, 12, 7, 7]),
  ];
}

/// 8 fake scans spread over weeks, to try grouping, search and filters.
/// Each call makes NEW ids, so you can insert them more than once.
List<ScanRecord> devSampleScans({String? userId, DateTime? now}) {
  final base = now ?? DateTime.now();
  ScanRecord make(Duration ago, List<int> ids, {double confidence = 0.9}) =>
      _make(
        id: const Uuid().v4(),
        createdAt: base.subtract(ago),
        classIds: ids,
        userId: userId,
        confidence: confidence,
      );

  return [
    make(const Duration(minutes: 25), [7, 7, 6, 5, 3, 4, 1]),
    make(const Duration(hours: 3), [14, 12, 11], confidence: 0.55),
    make(const Duration(days: 1, hours: 2), [15, 12, 7, 7]),
    make(const Duration(days: 2), [9, 9, 8, 2, 2]),
    make(const Duration(days: 5), [16, 17, 18]),
    make(const Duration(days: 9), [10, 11, 13, 19]),
    make(const Duration(days: 20), [8, 8, 8, 6, 4]),
    make(const Duration(days: 45), [14, 15, 12, 12]),
  ];
}
