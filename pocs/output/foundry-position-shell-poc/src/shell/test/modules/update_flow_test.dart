// D8.3: Update Orchestration Tests

import 'package:flutter_test/flutter_test.dart';
import 'package:foundry_shell/modules/module_updater.dart';

void main() {
  group('ModuleUpdater', () {
    late ModuleUpdater updater;

    setUp(() {
      updater = ModuleUpdater.instance;
    });

    test('Check for updates returns result', () async {
      final result = await updater.checkForUpdates('test-module');

      expect(result, isNotNull);
      expect(result.checkedAt, isNotNull);
    });

    test('Update state starts as idle', () {
      final state = updater.getUpdateState('new-module');

      expect(state.status, UpdateStatus.idle);
      expect(state.moduleId, 'new-module');
    });

    test('Background checker can be started and stopped', () {
      updater.startBackgroundUpdateChecker();
      // Should not throw when called multiple times
      updater.startBackgroundUpdateChecker();

      updater.stopBackgroundUpdateChecker();
    });

    test('Update event stream is available', () {
      expect(updater.updateEventStream, isNotNull);
    });

    test('Cancel update when idle returns success', () async {
      await updater.cancelUpdate('idle-module');
      // Should complete without error
    });

    test('Check all modules for updates returns map', () async {
      final results = await updater.checkAllModulesForUpdates();

      expect(results, isA<Map<String, UpdateCheckResult>>());
    });
  });
}
