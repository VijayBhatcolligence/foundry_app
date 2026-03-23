// Phase 3: Update Scheduler Unit Tests

import 'package:flutter_test/flutter_test.dart';
import 'package:foundry_shell/modules/update_scheduler.dart';

void main() {
  group('UpdateScheduler', () {
    late UpdateScheduler scheduler;

    setUp(() {
      scheduler = UpdateScheduler.instance;
    });

    tearDown(() async {
      await scheduler.stop();
    });

    test('starts periodic update checks', () async {
      await scheduler.start();

      expect(scheduler.isRunning, isTrue);
    });

    test('stops periodic update checks', () async {
      await scheduler.start();
      await scheduler.stop();

      expect(scheduler.isRunning, isFalse);
    });

    test('check interval is 4 hours', () {
      expect(scheduler.checkInterval, const Duration(hours: 4));
      expect(scheduler.checkInterval.inHours, 4);
      expect(scheduler.checkInterval.inMilliseconds, 14400000);
    });

    test('tracks next check time', () async {
      await scheduler.start();

      final nextCheck = await scheduler.getNextCheckTime();

      expect(nextCheck, isNotNull);
      expect(nextCheck!.isAfter(DateTime.now()), isTrue);
    });

    test('manual check now triggers immediately', () async {
      await scheduler.start();

      // This should trigger an immediate check
      await scheduler.checkNow();

      // No error should be thrown
      expect(scheduler.isRunning, isTrue);
    });

    test('does not start if already running', () async {
      await scheduler.start();
      await scheduler.start(); // Second start

      expect(scheduler.isRunning, isTrue);
      // Should handle gracefully without error
    });
  });
}
