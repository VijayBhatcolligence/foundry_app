// Phase 3.5: Module Selection Screen Widget Tests
// Purpose: Widget tests for ModuleSelectionScreen

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundry_shell/ui/module_selection_screen.dart';
import 'package:foundry_shell/position/position_resolver.dart';
import 'package:foundry_shell/modules/module_registry.dart';

void main() {
  group('ModuleSelectionScreen Widget Tests', () {
    late Position testPosition;
    late ModuleRegistry registry;

    setUp(() async {
      testPosition = Position(
        positionId: 'test-001',
        positionName: 'Test Worker',
        orgId: 'test-org',
        roleContext: {},
      );

      registry = ModuleRegistry.instance;
      await registry.loadRegistry('mock://registry');
    });

    testWidgets('Renders grid of module cards', (WidgetTester tester) async {
      String? selectedModuleId;

      await tester.pumpWidget(
        MaterialApp(
          home: ModuleSelectionScreen(
            currentPosition: testPosition,
            onModuleSelected: (moduleId) {
              selectedModuleId = moduleId;
            },
          ),
        ),
      );

      // Wait for loading to complete
      await tester.pumpAndSettle();

      // Should show 3 module cards
      expect(find.byType(Card), findsNWidgets(3));
    });

    testWidgets('Shows loading state initially', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ModuleSelectionScreen(
            currentPosition: testPosition,
            onModuleSelected: (moduleId) {},
          ),
        ),
      );

      // Should show loading indicator before modules load
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Wait for loading to complete
      await tester.pumpAndSettle();

      // Loading indicator should be gone
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('Displays module metadata correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ModuleSelectionScreen(
            currentPosition: testPosition,
            onModuleSelected: (moduleId) {},
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check for display names
      expect(find.text('Warehouse Clerk'), findsOneWidget);
      expect(find.text('Inventory Manager'), findsOneWidget);
      expect(find.text('Quality Inspector'), findsOneWidget);

      // Check for versions
      expect(find.text('v1.0.0'), findsNWidgets(3));
    });

    testWidgets('Calls onModuleSelected when card tapped', (WidgetTester tester) async {
      String? selectedModuleId;

      await tester.pumpWidget(
        MaterialApp(
          home: ModuleSelectionScreen(
            currentPosition: testPosition,
            onModuleSelected: (moduleId) {
              selectedModuleId = moduleId;
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap on Warehouse card
      await tester.tap(find.text('Warehouse Clerk'));
      await tester.pumpAndSettle();

      // Verify callback was called with correct moduleId
      expect(selectedModuleId, 'sample-warehouse');
    });

    testWidgets('Shows AppBar with correct title', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ModuleSelectionScreen(
            currentPosition: testPosition,
            onModuleSelected: (moduleId) {},
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Select Position Module'), findsOneWidget);
    });

    testWidgets('Has no back button in AppBar', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ModuleSelectionScreen(
            currentPosition: testPosition,
            onModuleSelected: (moduleId) {},
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should not have a back button
      expect(find.byIcon(Icons.arrow_back), findsNothing);
    });
  });
}
