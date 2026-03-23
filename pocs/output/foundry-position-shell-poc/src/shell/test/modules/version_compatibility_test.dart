// D8.1: Version Compatibility Tests
// Tests for semantic version validation and compatibility checking

import 'package:flutter_test/flutter_test.dart';
import 'package:foundry_shell/modules/compatibility_checker.dart';

void main() {
  group('CompatibilityChecker', () {
    late CompatibilityChecker checker;

    setUp(() {
      checker = CompatibilityChecker();
    });

    test('Compatible caret range passes', () async {
      final result = await checker.checkCompatibility(
        moduleId: 'test',
        moduleVersion: '1.0.0',
        requiredShellVersion: '^1.0.0',
      );

      expect(result.isCompatible, true);
      expect(result.shellVersion, '1.0.0');
    });

    test('Incompatible version fails', () async {
      final result = await checker.checkCompatibility(
        moduleId: 'test',
        moduleVersion: '1.0.0',
        requiredShellVersion: '^2.0.0', // Requires shell 2.x
      );

      expect(result.isCompatible, false);
      expect(result.incompatibilityReason, contains('Requires shell version'));
    });

    test('Exact version match', () async {
      final result = await checker.checkCompatibility(
        moduleId: 'test',
        moduleVersion: '1.0.0',
        requiredShellVersion: '1.0.0',
      );

      expect(result.isCompatible, true);
    });

    test('Tilde range compatibility', () async {
      final result = await checker.checkCompatibility(
        moduleId: 'test',
        moduleVersion: '1.0.0',
        requiredShellVersion: '~1.0.0',
      );

      expect(result.isCompatible, true);
    });

    test('Greater-than-or-equal range', () async {
      final result = await checker.checkCompatibility(
        moduleId: 'test',
        moduleVersion: '1.0.0',
        requiredShellVersion: '>=1.0.0',
      );

      expect(result.isCompatible, true);
    });

    test('Invalid version range returns error', () async {
      final result = await checker.checkCompatibility(
        moduleId: 'test',
        moduleVersion: '1.0.0',
        requiredShellVersion: 'invalid',
      );

      expect(result.isCompatible, false);
      expect(result.incompatibilityReason, contains('Invalid version range'));
    });

    test('VersionRange allows() method works correctly', () {
      final range = checker.parseVersionRange('^1.0.0');

      expect(range.allows('1.0.0'), true);
      expect(range.allows('1.5.0'), true);
      expect(range.allows('1.99.99'), true);
      expect(range.allows('2.0.0'), false);
      expect(range.allows('0.9.0'), false);
    });

    test('Major version 0 special handling', () {
      final range = checker.parseVersionRange('^0.1.0');

      // For major version 0, ^0.1.0 means >=0.1.0 <0.2.0
      expect(range.allows('0.1.0'), true);
      expect(range.allows('0.1.5'), true);
      expect(range.allows('0.2.0'), false);
    });

    test('Shell version can be retrieved', () {
      final version = checker.getCurrentShellVersion();
      expect(version, '1.0.0');
    });
  });
}
