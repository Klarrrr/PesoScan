import 'dart:math' as math;
// ignore: unnecessary_import
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Builds a short two-note "ding" as a WAV file in memory, so the app
/// needs no sound file.
///
/// To use your own sound later: put chime.mp3 in assets/sounds/ and, in
/// _playChime() below, play AssetSource('sounds/chime.mp3') instead.
Uint8List buildChimeWav({int sampleRate = 22050}) {
  // (frequency in Hz, length in seconds)
  const notes = [(880.0, 0.09), (1318.5, 0.16)];

  final samples = <int>[];
  for (final (frequency, seconds) in notes) {
    final count = (sampleRate * seconds).round();
    for (var i = 0; i < count; i++) {
      // Fade in and out quickly so the sound does not "click".
      final fade = math.min(
        1.0,
        math.min(i / 200, (count - i) / (count * 0.6)),
      );
      final wave = math.sin(2 * math.pi * frequency * i / sampleRate);
      samples.add((wave * fade * 0.55 * 32767).round());
    }
  }

  // A WAV file is a 44-byte header followed by the raw samples.
  final dataSize = samples.length * 2; // 16-bit = 2 bytes per sample
  final bytes = ByteData(44 + dataSize);

  void writeText(int offset, String text) {
    for (var i = 0; i < text.length; i++) {
      bytes.setUint8(offset + i, text.codeUnitAt(i));
    }
  }

  writeText(0, 'RIFF');
  bytes.setUint32(4, 36 + dataSize, Endian.little);
  writeText(8, 'WAVE');
  writeText(12, 'fmt ');
  bytes.setUint32(16, 16, Endian.little); // size of this block
  bytes.setUint16(20, 1, Endian.little); // 1 = plain PCM
  bytes.setUint16(22, 1, Endian.little); // mono
  bytes.setUint32(24, sampleRate, Endian.little);
  bytes.setUint32(28, sampleRate * 2, Endian.little); // bytes per second
  bytes.setUint16(32, 2, Endian.little); // bytes per sample frame
  bytes.setUint16(34, 16, Endian.little); // bits per sample
  writeText(36, 'data');
  bytes.setUint32(40, dataSize, Endian.little);
  for (var i = 0; i < samples.length; i++) {
    bytes.setInt16(44 + i * 2, samples[i], Endian.little);
  }
  return bytes.buffer.asUint8List();
}

/// Vibration and sound for the scanner. Callers pass the user's two
/// Settings switches, so this class never reads settings itself.
class FeedbackService {
  FeedbackService._();
  static final FeedbackService instance = FeedbackService._();

  // Created only when first needed (keeps unit tests free of audio plugins).
  AudioPlayer? _player;
  AudioPlayer get _audio => _player ??= AudioPlayer();

  final Uint8List _chime = buildChimeWav();
  DateTime _lastLockFeedback = DateTime.fromMillisecondsSinceEpoch(0);

  /// A new coin or bill was locked in. Rate-limited so a burst of
  /// detections gives one ding, not ten.
  Future<void> itemLocked({required bool haptic, required bool audio}) async {
    final now = DateTime.now();
    if (now.difference(_lastLockFeedback) < const Duration(milliseconds: 250)) {
      return;
    }
    _lastLockFeedback = now;
    if (haptic) HapticFeedback.lightImpact();
    if (audio) await _playChime();
  }

  /// The capture button was pressed.
  Future<void> captured({required bool haptic}) async {
    if (haptic) await HapticFeedback.mediumImpact();
  }

  /// The scan was saved.
  Future<void> saved({required bool haptic, required bool audio}) async {
    if (haptic) await HapticFeedback.heavyImpact();
    if (audio) await _playChime();
  }

  Future<void> _playChime() async {
    try {
      await _audio.stop();
      await _audio.play(BytesSource(_chime));
    } catch (e) {
      debugPrint('Could not play the chime: $e');
    }
  }
}
