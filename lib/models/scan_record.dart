import 'dart:convert';

// "as math" avoids a name clash: our getter below is also called totalCentavos.
import '../core/scan_math.dart' as math;
import 'detection.dart';

/// One saved scan, exactly what the History screen will show.
class ScanRecord {
  final String id;
  final DateTime createdAt;

  /// Path of the frozen photo saved on the phone.
  final String imagePath;

  /// Which account made the scan (history is per user).
  final String? userId;

  final List<Detection> detections;

  const ScanRecord({
    required this.id,
    required this.createdAt,
    required this.imagePath,
    required this.detections,
    this.userId,
  });

  int get totalCentavos => math.totalCentavos(detections);
  int get itemCount => detections.length;

  /// Row for the SQLite table (Part 13).
  /// total_centavos and item_count are stored separately on purpose:
  /// the Statistics screen can then add them up with one fast SQL query
  /// instead of decoding every scan's JSON.
  Map<String, Object?> toMap() => {
    'id': id,
    'user_id': userId,
    'created_at': createdAt.millisecondsSinceEpoch,
    'image_path': imagePath,
    'total_centavos': totalCentavos,
    'item_count': itemCount,
    'detections_json': jsonEncode(detections.map((d) => d.toJson()).toList()),
  };

  factory ScanRecord.fromMap(Map<String, Object?> map) {
    final list = jsonDecode(map['detections_json'] as String) as List;
    return ScanRecord(
      id: map['id'] as String,
      userId: map['user_id'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      imagePath: map['image_path'] as String,
      detections: list
          .map((e) => Detection.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }
}
