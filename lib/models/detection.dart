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

  /// Convert to a plain Map so it can be stored as JSON text.
  Map<String, dynamic> toJson() => {
    'class_id': money.id,
    'confidence': confidence,
    'box': [box.left, box.top, box.right, box.bottom],
  };

  /// Rebuild a Detection from the Map made by toJson().
  factory Detection.fromJson(Map<String, dynamic> json) {
    final b = (json['box'] as List).map((e) => (e as num).toDouble()).toList();
    return Detection(
      money: MoneyClasses.byId(json['class_id'] as int),
      confidence: (json['confidence'] as num).toDouble(),
      box: Rect.fromLTRB(b[0], b[1], b[2], b[3]),
    );
  }
}
