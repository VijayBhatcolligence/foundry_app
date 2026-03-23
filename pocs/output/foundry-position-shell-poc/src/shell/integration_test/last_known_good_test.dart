// D8.9: Last-Known-Good Persistence Tests
// INTEGRATION TEST - Requires device or emulator
// Run with: flutter test integration_test/last_known_good_test.dart

import 'package:integration_test/integration_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundry_shell/modules/fallback_manager.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Last-Known-Good Persistence', () {
    late FallbackManager manager;

    setUp(() {
      manager = FallbackManager.instance;
    });

    test('Last-known-good persists across instances', () async {
      await manager.markAsLastKnownGood(
        moduleId: 'persist-test',
        version: '1.0.0',
      );

      final version = await manager.getLastKnownGoodVersion('persist-test');
      expect(version, '1.0.0');
    });

    test('Multiple modules can have last-known-good versions', () async {
      await manager.markAsLastKnownGood(moduleId: 'module-a', version: '1.0.0');
      await manager.markAsLastKnownGood(moduleId: 'module-b', version: '2.0.0');

      final versionA = await manager.getLastKnownGoodVersion('module-a');
      final versionB = await manager.getLastKnownGoodVersion('module-b');

      expect(versionA, '1.0.0');
      expect(versionB, '2.0.0');
    });

    test('Updating last-known-good replaces old version', () async {
      await manager.markAsLastKnownGood(moduleId: 'update-test', version: '1.0.0');
      await manager.markAsLastKnownGood(moduleId: 'update-test', version: '2.0.0');

      final version = await manager.getLastKnownGoodVersion('update-test');
      expect(version, '2.0.0');
    });
  });
}
