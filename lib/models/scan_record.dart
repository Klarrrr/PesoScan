import 'dart:convert';

import '../core/scan_math.dart' as math;
import 'detection.dart';

/// Represents a single photo and its specific detections within a multi-frame session.
class ScanFrame {
  final String imagePath;
  final List<Detection> detections;

  ScanFrame({required this.imagePath, required this.detections});

  int get frameTotalCentavos => math.totalCentavos(detections);
  int get itemCount => detections.length;

  Map<String, dynamic> toJson() => {
    'imagePath': imagePath,
    'detections': detections.map((d) => d.toJson()).toList(),
  };

  factory ScanFrame.fromJson(Map<String, dynamic> json) {
    final rawDetections = (json['detections'] as List?) ?? const [];
    return ScanFrame(
      imagePath: (json['imagePath'] as String?) ?? '',
      detections: rawDetections
          .map((e) => Detection.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }
}

/// One saved history record, which now contains MULTIPLE frames (photos).
class ScanRecord {
  final String id;
  final DateTime createdAt;
  final String? userId;
  final List<ScanFrame> frames;

  const ScanRecord({
    required this.id,
    required this.createdAt,
    required this.frames,
    this.userId,
  });

  int get totalCentavos =>
      frames.fold(0, (sum, f) => sum + f.frameTotalCentavos);
  int get itemCount => frames.fold(0, (sum, f) => sum + f.itemCount);

  String get imagePath {
    if (frames.isNotEmpty) {
      return frames.first.imagePath;
    }
    return '';
  }

  List<Detection> get detections => frames.expand((f) => f.detections).toList();

  ScanRecord copyWith({String? imagePath, List<Detection>? detections}) {
    List<ScanFrame> newFrames = List.from(frames);

    if (imagePath != null) {
      newFrames = newFrames
          .map((f) => ScanFrame(imagePath: imagePath, detections: f.detections))
          .toList();
    }

    return ScanRecord(
      id: id,
      userId: userId,
      createdAt: createdAt,
      frames: newFrames,
    );
  }

  Map<String, Object?> toMap() => {
    'id': id,
    'user_id': userId,
    'created_at': createdAt.millisecondsSinceEpoch,
    'total_centavos': totalCentavos,
    'item_count': itemCount,
    'image_path': imagePath,
    'detections_json': jsonEncode(frames.map((f) => f.toJson()).toList()),
  };

  factory ScanRecord.fromMap(Map<String, Object?> map) {
    final rawJson = (map['detections_json'] ?? map['frames_json']) as String?;
    final list = rawJson != null ? (jsonDecode(rawJson) as List) : const [];

    List<ScanFrame> parsedFrames = [];

    if (list.isNotEmpty) {
      final firstItem = Map<String, dynamic>.from(list.first as Map);

      // Check if the saved JSON uses the multi-frame ScanFrame structure
      if (firstItem.containsKey('detections') ||
          firstItem.containsKey('imagePath')) {
        parsedFrames = list
            .map((e) => ScanFrame.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      } else {
        // Fallback for older single-frame Detection records
        final legacyDetections = list
            .map((e) => Detection.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        parsedFrames = [
          ScanFrame(
            imagePath: (map['image_path'] as String?) ?? '',
            detections: legacyDetections,
          ),
        ];
      }
    }

    return ScanRecord(
      id: map['id'] as String,
      userId: map['user_id'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      frames: parsedFrames,
    );
  }
}
