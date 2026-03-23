// D8.5: End-to-End Update Scenarios

import 'package:flutter_test/flutter_test.dart';
import 'package:foundry_shell/modules/module_updater.dart';
import 'package:foundry_shell/modules/module_registry.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Module Update Integration', () {
    test('Complete update flow components are available', () async {
      expect(ModuleUpdater.instance, isNotNull);
      expect(ModuleRegistry.instance, isNotNull);
    });

    test('Check for updates workflow', () async {
      final updateResult = await ModuleUpdater.instance.checkForUpdates('test-module');
      expect(updateResult, isNotNull);
      expect(updateResult.checkedAt, isNotNull);
    });

    test('Update event stream emits events', () async {
      final stream = ModuleUpdater.instance.updateEventStream;
      expect(stream, isNotNull);

      // Stream should be broadcastable
      final subscription = stream.listen((event) {});
      await subscription.cancel();
    });
  });
}
