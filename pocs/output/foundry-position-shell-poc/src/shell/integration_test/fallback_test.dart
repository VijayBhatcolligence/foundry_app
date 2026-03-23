// D8.4: Automatic Rollback Tests
// INTEGRATION TEST - Requires device or emulator
// Run with: flutter test integration_test/fallback_test.dart

import 'package:integration_test/integration_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundry_shell/modules/fallback_manager.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('FallbackManager', () {
    late FallbackManager manager;

    setUp(() {
      manager = FallbackManager.instance;
    });

    tearDown(() async {
      // Clean up test data
      await manager.resetFailures('test-module');
    });

    test('Record load failure increments count', () async {
      await manager.recordLoadFailure(
        moduleId: 'test-module',
        version: '1.0.0',
        error: 'Test error',
      );

      final count = await manager.getFailureCount('test-module', '1.0.0');
      expect(count, greaterThan(0));
    });

    test('Mark as last-known-good stores version', () async {
      await manager.markAsLastKnownGood(
        moduleId: 'test-module',
        version: '1.0.0',
      );

      final version = await manager.getLastKnownGoodVersion('test-module');
      expect(version, '1.0.0');
    });

    test('Get last-known-good for new module returns null', () async {
      final version = await manager.getLastKnownGoodVersion('new-module');
      expect(version, null);
    });

    test('Reset failures clears count', () async {
      await manager.recordLoadFailure(
        moduleId: 'test-module',
        version: '1.0.0',
        error: 'Error',
      );

      await manager.resetFailures('test-module');

      final count = await manager.getFailureCount('test-module', '1.0.0');
      expect(count, 0);
    });

    test('Attempt fallback when no last-known-good returns error', () async {
      final result = await manager.attemptFallback('unknown-module');

      expect(result.success, false);
      expect(result.error, contains('No known-good version'));
      expect(result.userNotificationRequired, true);
    });

    test('isBlocked returns false for new module', () async {
      final blocked = await manager.isBlocked('new-module', '1.0.0');
      expect(blocked, false);
    });

    test('Multiple failures increment count', () async {
      for (int i = 0; i < 3; i++) {
        await manager.recordLoadFailure(
          moduleId: 'failing-module',
          version: '2.0.0',
          error: 'Error $i',
        );
      }

      final count = await manager.getFailureCount('failing-module', '2.0.0');
      expect(count, 3);
    });
  });
}
