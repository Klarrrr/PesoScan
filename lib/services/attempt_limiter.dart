import 'package:shared_preferences/shared_preferences.dart';

/// Counts wrong attempts and locks for a while after too many.
/// It is saved on the phone, so closing the app does not reset it.
class AttemptLimiter {
  final int maxAttempts;
  final Duration lockDuration;
  final DateTime Function() _now;

  /// `now` can be replaced in tests to fake the passing of time.
  AttemptLimiter({
    this.maxAttempts = 5,
    this.lockDuration = const Duration(minutes: 5),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  String _countKey(String key) => 'fail_count_$key';
  String _lockKey(String key) => 'lock_until_$key';

  /// How long is left on the lock, or null if not locked.
  Future<Duration?> lockRemaining(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final until = prefs.getInt(_lockKey(key));
    if (until == null) return null;

    final remaining = DateTime.fromMillisecondsSinceEpoch(until)
        .difference(_now());
    if (remaining <= Duration.zero) {
      await prefs.remove(_lockKey(key));
      return null;
    }
    return remaining;
  }

  /// Records one wrong attempt. Returns how many are LEFT (0 = now locked).
  Future<int> recordFailure(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final count = (prefs.getInt(_countKey(key)) ?? 0) + 1;

    if (count >= maxAttempts) {
      await prefs.setInt(
        _lockKey(key),
        _now().add(lockDuration).millisecondsSinceEpoch,
      );
      await prefs.remove(_countKey(key));
      return 0;
    }
    await prefs.setInt(_countKey(key), count);
    return maxAttempts - count;
  }

  /// Call after a success.
  Future<void> reset(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_countKey(key));
    await prefs.remove(_lockKey(key));
  }

  /// 4:05 style text for "try again in ...".
  static String format(Duration d) {
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '${d.inMinutes}:$seconds';
  }
}
