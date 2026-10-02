import 'dart:ui' show Rect;

import '../core/constants.dart';
import 'money_class.dart';

/// How sure the model is, in three steps (green / amber / red).
enum ConfidenceLevel { high, medium, low }

/// One coin or bill found in one frame.
class Detection {
  final MoneyClass money;

  /// 0.0 to 1.0
  final double confidence;

  /// Bounding box in NORMALIZED coordinates (0.0 to 1.0 of the frame).
  final Rect box;

  /// True once the user checked or corrected this item by hand.
  final bool verified;

  const Detection({
    required this.money,
    required this.confidence,
    required this.box,
    this.verified = false,
  });

  int get valueCentavos => money.valueCentavos;

  /// A human-checked item is never "low confidence".
  bool get isLowConfidence =>
      !verified && confidence < AppConstants.lowConfidenceThreshold;

  ConfidenceLevel get level {
    if (verified || confidence >= AppConstants.highConfidenceThreshold) {
      return ConfidenceLevel.high;
    }
    if (confidence >= AppConstants.lowConfidenceThreshold) {
      return ConfidenceLevel.medium;
    }
    return ConfidenceLevel.low;
  }

  /// "87%"
  String get confidencePercent => '${(confidence * 100).round()}%';

  Detection copyWith({
    MoneyClass? money,
    double? confidence,
    Rect? box,
    bool? verified,
  }) {
    return Detection(
      money: money ?? this.money,
      confidence: confidence ?? this.confidence,
      box: box ?? this.box,
      verified: verified ?? this.verified,
    );
  }

  Map<String, dynamic> toJson() => {
    'class_id': money.id,
    'confidence': confidence,
    'box': [box.left, box.top, box.right, box.bottom],
    if (verified) 'verified': true,
  };

  factory Detection.fromJson(Map<String, dynamic> json) {
    final b = (json['box'] as List).map((e) => (e as num).toDouble()).toList();
    return Detection(
      money: MoneyClasses.byId(json['class_id'] as int),
      confidence: (json['confidence'] as num).toDouble(),
      box: Rect.fromLTRB(b[0], b[1], b[2], b[3]),
      verified: json['verified'] == true,
    );
  }
}
