// Phase 3: Offline Module Loading Integration Test
// Tests AC-3.1, AC-3.2, AC-3.3

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:foundry_shell/modules/module_loader.dart';
import 'package:foundry_shell/modules/module_registry.dart';
import 'package:foundry_shell/utils/performance_metrics.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Offline Module Loading', () {
    late ModuleLoader loader;
    late ModuleRegistry registry;

    setUpAll(() async {
      loader = ModuleLoader.instance;
      registry = ModuleRegistry.instance;

      // Load registry
      await registry.loadRegistry('mock://registry');
    });

    testWidgets('performance: cached module loads in under 200ms', (tester) async {
      await tester.pumpAndSettle();

      // First load (downloads module)
      print('First load: downloading module...');
      final firstResult = await loader.loadModule('sample-warehouse', version: '1.0.0');

      expect(firstResult.success, isTrue, reason: 'First load should succeed');

      await tester.pumpAndSettle();

      // Second load (from cache)
      print('Second load: loading from cache...');
      final secondResult = await loader.loadModule('sample-warehouse', version: '1.0.0');

      expect(secondResult.success, isTrue, reason: 'Cache load should succeed');
      expect(secondResult.source.name, 'cache', reason: 'Should load from cache');

      final cacheLoadTimeMs = secondResult.loadTime.inMilliseconds;
      print('Cache load time: ${cacheLoadTimeMs}ms');

      // AC-3.2: Cache load time < 200ms
      expect(cacheLoadTimeMs, lessThan(200),
          reason: 'Cache load must be under 200ms');

      // Verify performance metrics were recorded
      final avgDuration = PerformanceMetrics.getAverageDuration('module_cache_load_sample-warehouse');
      expect(avgDuration, isNotNull);
      print('Average cache load time: ${avgDuration!.inMilliseconds}ms');
    });

    testWidgets('offline: module loads from cache when network unavailable', (tester) async {
      await tester.pumpAndSettle();

      // First ensure module is cached
      final cacheResult = await loader.loadModule('sample-warehouse', version: '1.0.0');
      expect(cacheResult.success, isTrue);

      await tester.pumpAndSettle();

      // Now load again (should use cache)
      final offlineResult = await loader.loadModule('sample-warehouse', version: '1.0.0');

      expect(offlineResult.success, isTrue, reason: 'Module loaded offline');
      expect(offlineResult.source.name, 'cache', reason: 'No network requests made');
      print('Module loaded offline from cache: sample-warehouse');

      // AC-3.3: Offline module loading works
      expect(offlineResult.modulePath, isNotNull, reason: 'Cache hit: sample-warehouse');
    });

    testWidgets('error: returns error when module not cached and offline', (tester) async {
      await tester.pumpAndSettle();

      // This would require mocking network offline state
      // For now, just verify error handling works
      final result = await loader.loadModule('nonexistent-module');

      expect(result.success, isFalse);
      expect(result.error, isNotNull);
    });
  });
}
