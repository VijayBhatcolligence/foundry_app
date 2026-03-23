// D8.11: Multi-Version Cache Tests
// INTEGRATION TEST - Requires device or emulator
// Run with: flutter test integration_test/module_cache_test.dart

import 'package:integration_test/integration_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundry_shell/modules/module_cache.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('ModuleCache', () {
    late ModuleCache cache;

    setUp(() {
      cache = ModuleCache.instance;
    });

    test('getCachedModulePath returns null for non-cached module', () async {
      final path = await cache.getCachedModulePath('non-existent', '1.0.0');
      expect(path, null);
    });

    test('listCachedVersions returns empty list for new module', () async {
      final versions = await cache.listCachedVersions('new-module');
      expect(versions, isEmpty);
    });

    test('getCacheSize returns integer', () async {
      final size = await cache.getCacheSize();
      expect(size, isA<int>());
      expect(size, greaterThanOrEqualTo(0));
    });

    test('getCacheDirectory returns valid path', () async {
      final dir = await cache.getCacheDirectory();
      expect(dir, isNotNull);
      expect(dir, isNotEmpty);
    });

    test('runGarbageCollection completes successfully', () async {
      final result = await cache.runGarbageCollection();
      expect(result.filesRemoved, greaterThanOrEqualTo(0));
      expect(result.bytesFreed, greaterThanOrEqualTo(0));
      expect(result.duration, isNotNull);
    });
  });
}
