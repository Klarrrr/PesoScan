import 'package:flutter_test/flutter_test.dart';
import 'package:pesoscan/services/attempt_limiter.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('locks after the maximum attempts and unlocks later', () async {
    var now = DateTime(2026, 10, 1, 12);
    final limiter = AttemptLimiter(
      maxAttempts: 3,
      lockDuration: const Duration(minutes: 5),
      now: () => now,
    );

    expect(await limiter.recordFailure('k'), 2);
    expect(await limiter.recordFailure('k'), 1);
    expect(await limiter.recordFailure('k'), 0); // locked now
    expect(await limiter.lockRemaining('k'), isNotNull);

    now = now.add(const Duration(minutes: 6));
    expect(await limiter.lockRemaining('k'), isNull);
    expect(await limiter.recordFailure('k'), 2); // counting starts over
  });

  test('a success resets the counter', () async {
    final limiter = AttemptLimiter(maxAttempts: 3);
    await limiter.recordFailure('k');
    await limiter.recordFailure('k');
    await limiter.reset('k');
    expect(await limiter.recordFailure('k'), 2);
  });

  test('keys are independent', () async {
    final limiter = AttemptLimiter(maxAttempts: 2);
    await limiter.recordFailure('a');
    await limiter.recordFailure('a');
    expect(await limiter.lockRemaining('a'), isNotNull);
    expect(await limiter.lockRemaining('b'), isNull);
  });

  test('format', () {
    expect(
      AttemptLimiter.format(const Duration(minutes: 4, seconds: 5)),
      '4:05',
    );
  });
}
