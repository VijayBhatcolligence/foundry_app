// D8.10: Incompatible Version Rejection Tests

import 'package:flutter_test/flutter_test.dart';
import 'package:foundry_shell/modules/compatibility_checker.dart';
import 'package:foundry_shell/modules/version_resolver.dart';

void main() {
  group('Incompatible Version Rejection', () {
    late CompatibilityChecker checker;
    late VersionResolver resolver;

    setUp(() {
      checker = CompatibilityChecker();
      resolver = VersionResolver();
    });

    test('Module requiring newer shell version is rejected', () async {
      final result = await checker.checkCompatibility(
        moduleId: 'future-module',
        moduleVersion: '1.0.0',
        requiredShellVersion: '^2.0.0',
      );

      expect(result.isCompatible, false);
      expect(result.incompatibilityReason, isNotNull);
    });

    test('Module requiring different major version is rejected', () async {
      final result = await checker.checkCompatibility(
        moduleId: 'old-module',
        moduleVersion: '1.0.0',
        requiredShellVersion: '^0.9.0',
      );

      expect(result.isCompatible, false);
    });

    test('isSafeUpgrade rejects major version changes', () {
      final safe = resolver.isSafeUpgrade('1.5.0', '2.0.0');
      expect(safe, false);
    });

    test('isSafeUpgrade rejects downgrades', () {
      final safe = resolver.isSafeUpgrade('2.0.0', '1.9.0');
      expect(safe, false);
    });

    test('isSafeUpgrade accepts minor version increase', () {
      final safe = resolver.isSafeUpgrade('1.0.0', '1.1.0');
      expect(safe, true);
    });

    test('isSafeUpgrade accepts patch version increase', () {
      final safe = resolver.isSafeUpgrade('1.0.0', '1.0.1');
      expect(safe, true);
    });
  });
}
