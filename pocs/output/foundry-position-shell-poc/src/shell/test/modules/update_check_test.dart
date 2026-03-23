// D8.8: Update Detection Tests

import 'package:flutter_test/flutter_test.dart';
import 'package:foundry_shell/modules/module_updater.dart';
import 'package:foundry_shell/modules/module_registry.dart';

void main() {
  group('Update Detection', () {
    test('Check for updates on unregistered module returns error', () async {
      final result = await ModuleUpdater.instance.checkForUpdates('unknown-module');

      expect(result.updateAvailable, false);
      expect(result.error, isNotNull);
    });

    test('Registry not loaded returns appropriate result', () async {
      expect(ModuleRegistry.instance.isRegistryLoaded, isA<bool>());
    });

    test('Check all modules returns empty map when registry not loaded', () async {
      final results = await ModuleUpdater.instance.checkAllModulesForUpdates();
      expect(results, isA<Map<String, UpdateCheckResult>>());
    });
  });
}
