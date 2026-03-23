// Phase 3.5: Module Registry Selection Tests
// Purpose: Unit tests for getModulesForSelection() method

import 'package:flutter_test/flutter_test.dart';
import 'package:foundry_shell/modules/module_registry.dart';

void main() {
  group('ModuleRegistry - Phase 3.5 Selection', () {
    late ModuleRegistry registry;

    setUp(() {
      registry = ModuleRegistry.instance;
    });

    test('getModulesForSelection returns unique modules', () async {
      // Load mock registry
      final result = await registry.loadRegistry('mock://registry');
      expect(result.success, true);

      // Get modules for selection
      final modules = await registry.getModulesForSelection();

      // Should return 3 unique modules
      expect(modules.length, 3);

      // Verify no duplicate moduleIds
      final moduleIds = modules.map((m) => m.moduleId).toSet();
      expect(moduleIds.length, 3);
    });

    test('getModulesForSelection returns latest version only', () async {
      // Load registry
      await registry.loadRegistry('mock://registry');

      // Get modules
      final modules = await registry.getModulesForSelection();

      // Each module should be the latest version (1.0.0 for all in mock)
      for (final module in modules) {
        expect(module.version, '1.0.0');
      }
    });

    test('getModulesForSelection sorts by displayName', () async {
      // Load registry
      await registry.loadRegistry('mock://registry');

      // Get modules
      final modules = await registry.getModulesForSelection();

      // Should be sorted: Inventory Manager, Quality Inspector, Warehouse Clerk
      expect(modules[0].displayName, 'Inventory Manager');
      expect(modules[1].displayName, 'Quality Inspector');
      expect(modules[2].displayName, 'Warehouse Clerk');
    });

    test('ModuleMetadata includes display fields', () async {
      // Load registry
      await registry.loadRegistry('mock://registry');

      // Get modules
      final modules = await registry.getModulesForSelection();

      // Verify each module has display metadata
      for (final module in modules) {
        expect(module.displayName, isNotEmpty);
        expect(module.description, isNotEmpty);
        expect(module.categoryId, isNotNull);
      }
    });

    test('Mock registry contains 3 modules with correct metadata', () async {
      // Load registry
      final result = await registry.loadRegistry('mock://registry');
      expect(result.success, true);
      expect(result.modulesLoaded, 3);

      // Get modules
      final modules = await registry.getModulesForSelection();

      // Warehouse module
      final warehouse = modules.firstWhere((m) => m.moduleId == 'sample-warehouse');
      expect(warehouse.displayName, 'Warehouse Clerk');
      expect(warehouse.description, contains('Receive goods'));
      expect(warehouse.categoryId, 'warehouse');

      // Inventory module
      final inventory = modules.firstWhere((m) => m.moduleId == 'sample-inventory');
      expect(inventory.displayName, 'Inventory Manager');
      expect(inventory.description, contains('Count inventory'));
      expect(inventory.categoryId, 'inventory');

      // Quality module
      final quality = modules.firstWhere((m) => m.moduleId == 'sample-quality');
      expect(quality.displayName, 'Quality Inspector');
      expect(quality.description, contains('Perform inspections'));
      expect(quality.categoryId, 'quality');
    });

    test('getModulesForSelection returns empty list when registry not loaded', () async {
      // Create a fresh registry instance (not loaded)
      final freshRegistry = ModuleRegistry();

      // Should return empty list
      final modules = await freshRegistry.getModulesForSelection();
      expect(modules, isEmpty);
    });
  });
}
