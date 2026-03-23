// D8.12: Update UI Notification Tests

import 'package:flutter_test/flutter_test.dart';
import 'package:foundry_shell/bridge/module_bridge_extension.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Update Notification Integration', () {
    late ModuleBridgeExtension bridge;

    setUp(() {
      bridge = ModuleBridgeExtension();
    });

    test('Bridge extension methods are callable', () async {
      final result = await bridge.getModuleVersion('test-module');
      expect(result, isA<Map<String, dynamic>>());
      expect(result['success'], isA<bool>());
    });

    test('Get update progress returns status', () async {
      final result = await bridge.getUpdateProgress('test-module');
      expect(result, isA<Map<String, dynamic>>());
      expect(result.containsKey('status'), true);
    });

    test('Check for updates via bridge', () async {
      final result = await bridge.checkForUpdates('test-module');
      expect(result, isA<Map<String, dynamic>>());
      expect(result.containsKey('success'), true);
    });
  });
}
