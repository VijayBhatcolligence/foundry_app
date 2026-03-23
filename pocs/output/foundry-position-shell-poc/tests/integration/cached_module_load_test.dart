// D8.13: Cache Load Performance Tests

import 'package:flutter_test/flutter_test.dart';
import 'package:foundry_shell/modules/module_cache.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Cached Module Load Performance', () {
    late ModuleCache cache;

    setUp(() {
      cache = ModuleCache.instance;
    });

    test('Cache operations complete within reasonable time', () async {
      final stopwatch = Stopwatch()..start();

      await cache.getCacheDirectory();
      await cache.listCachedVersions('test-module');
      await cache.getCacheSize();

      stopwatch.stop();

      // All operations should complete in under 5 seconds
      expect(stopwatch.elapsedMilliseconds, lessThan(5000));
    });

    test('getCachedModulePath is fast for non-existent module', () async {
      final stopwatch = Stopwatch()..start();

      await cache.getCachedModulePath('non-existent', '1.0.0');

      stopwatch.stop();

      // Should complete in under 500ms
      expect(stopwatch.elapsedMilliseconds, lessThan(500));
    });

    test('Garbage collection completes in reasonable time', () async {
      final stopwatch = Stopwatch()..start();

      final result = await cache.runGarbageCollection();

      stopwatch.stop();

      expect(result.duration.inSeconds, lessThan(10));
    });
  });
}
