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

  factory ScanFrame.fromJson(Map<String, dynamic> json) => ScanFrame(
    imagePath: json['imagePath'] as String,
    detections: (json['detections'] as List)
        .map((e) => Detection.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
  );
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

  // The grand total is the sum of all individual frames
  int get totalCentavos =>
      frames.fold(0, (sum, f) => sum + f.frameTotalCentavos);
  int get itemCount => frames.fold(0, (sum, f) => sum + f.itemCount);

  // Return the first image to use as the thumbnail in the History List screen
  String get imagePath => frames.isNotEmpty ? frames.first.imagePath : '';

  // --- FIX 1: Backward compatibility for scan_search and scan_stats ---
  // This automatically combines all items from all frames into one flat list.
  List<Detection> get detections => frames.expand((f) => f.detections).toList();

  // --- FIX 2: Re-added copyWith for history_provider ---
  // HistoryProvider uses this to remove photos (clear cache) by passing imagePath: ''
  ScanRecord copyWith({String? imagePath, List<Detection>? detections}) {
    List<ScanFrame> newFrames = List.from(frames);

    // If history_provider is clearing the photo cache, remove the image path from all frames
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
    'image_path':
        imagePath, // Keep for backward compatibility with the SQL table
    'frames_json': jsonEncode(frames.map((f) => f.toJson()).toList()),
  };

  factory ScanRecord.fromMap(Map<String, Object?> map) {
    // If it's an old single-image record (before this update), this handles it gracefully
    if (map['frames_json'] == null) {
      final list = jsonDecode(map['detections_json'] as String) as List;
      final detections = list
          .map((e) => Detection.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      return ScanRecord(
        id: map['id'] as String,
        userId: map['user_id'] as String?,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          map['created_at'] as int,
        ),
        frames: [
          ScanFrame(
            imagePath: map['image_path'] as String,
            detections: detections,
          ),
        ],
      );
    }

    // Load new multi-frame records
    final list = jsonDecode(map['frames_json'] as String) as List;
    return ScanRecord(
      id: map['id'] as String,
      userId: map['user_id'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      frames: list
          .map((e) => ScanFrame.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }
}
