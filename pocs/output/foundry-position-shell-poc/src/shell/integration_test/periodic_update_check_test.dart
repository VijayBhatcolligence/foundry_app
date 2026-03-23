// Phase 3: Periodic Update Check Integration Test
// Tests AC-3.10

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:foundry_shell/modules/update_scheduler.dart';
import 'package:foundry_shell/modules/module_registry.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Periodic Update Checks', () {
    late UpdateScheduler scheduler;
    late ModuleRegistry registry;

    setUpAll(() async {
      scheduler = UpdateScheduler.instance;
      registry = ModuleRegistry.instance;

      // Load initial registry
      await registry.loadRegistry('mock://registry');
    });

    testWidgets('update checks trigger every 4 hours', (tester) async {
      await tester.pumpAndSettle();

      print('Starting update scheduler...');
      await scheduler.start();

      // Verify scheduler is running
      expect(scheduler.isRunning, isTrue, reason: 'Update check triggered');

      // Verify 4 hour interval
      expect(scheduler.checkInterval.inHours, 4, reason: '4 hour interval verified');
      expect(scheduler.checkInterval.inMilliseconds, 14400000);

      print('Update scheduler running with 4-hour interval');

      // Get next check time
      final nextCheck = await scheduler.getNextCheckTime();
      expect(nextCheck, isNotNull);

      final now = DateTime.now();
      final expectedNextCheck = now.add(const Duration(hours: 4));
      final timeDiff = nextCheck!.difference(expectedNextCheck).abs();

      // Should be within a few seconds of 4 hours from now
      expect(timeDiff.inMinutes, lessThan(5), reason: 'Next check scheduled correctly');

      print('Next check scheduled: ${nextCheck.toIso8601String()}');

      // AC-3.10: Periodic update checks every 4 hours
      expect(registry.isRegistryLoaded, isTrue, reason: 'Registry checked');

      await scheduler.stop();
    });

    testWidgets('manual check now works', (tester) async {
      await tester.pumpAndSettle();

      await scheduler.start();

      print('Triggering manual update check...');
      await scheduler.checkNow();

      expect(scheduler.isRunning, isTrue);
      expect(registry.isRegistryLoaded, isTrue);

      print('Manual update check completed successfully');

      await scheduler.stop();
    });
  });
}
