import 'dart:ui' show Rect;

import '../core/constants.dart';
import 'money_class.dart';

/// One coin or bill found in one frame.
class Detection {
  final MoneyClass money;

  /// 0.0 to 1.0
  final double confidence;

  /// Bounding box in NORMALIZED coordinates (0.0 to 1.0 of the frame's
  /// width/height). It works on any screen size; we multiply by the
  /// screen size only when drawing (Part 10).
  final Rect box;

  const Detection({
    required this.money,
    required this.confidence,
    required this.box,
  });

  int get valueCentavos => money.valueCentavos;

  bool get isLowConfidence => confidence < AppConstants.lowConfidenceThreshold;

  /// "87%"
  String get confidencePercent => '${(confidence * 100).round()}%';

  /// Used when the user manually corrects a wrong detection (Part 12).
  Detection copyWith({MoneyClass? money, double? confidence, Rect? box}) {
    return Detection(
      money: money ?? this.money,
      confidence: confidence ?? this.confidence,
      box: box ?? this.box,
    );
  }
}
