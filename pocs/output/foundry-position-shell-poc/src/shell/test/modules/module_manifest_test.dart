// D8.6: Module Manifest Parsing Tests
// Tests for AC-1: Module manifest loads and parses correctly

import 'package:flutter_test/flutter_test.dart';
import 'package:foundry_shell/modules/module_manifest.dart';

void main() {
  group('ModuleManifest', () {
    test('Valid manifest with all required fields parses successfully', () {
      final json = {
        'moduleId': 'test-module',
        'version': '1.0.0',
        'requiredShellVersion': '^1.0.0',
        'signature': 'A' * 344, // 344 base64 characters
        'downloadUrl': 'https://example.com/module.js',
        'checksum': 'a' * 64, // 64 hex characters
        'downloadSizeBytes': 1024,
        'publishedAt': '2026-03-14T10:00:00Z',
        'metadata': {'test': 'value'},
      };

      final manifest = ModuleManifest.fromJson(json);

      expect(manifest.moduleId, 'test-module');
      expect(manifest.version, '1.0.0');
      expect(manifest.requiredShellVersion, '^1.0.0');
      expect(manifest.signature.length, 344);
      expect(manifest.checksum.length, 64);
      expect(manifest.downloadUrl, 'https://example.com/module.js');
      expect(manifest.downloadSizeBytes, 1024);
      expect(manifest.metadata['test'], 'value');
    });

    test('Missing required field throws FormatException with field name', () {
      final json = {
        // Missing moduleId
        'version': '1.0.0',
        'requiredShellVersion': '^1.0.0',
        'signature': 'A' * 344,
        'downloadUrl': 'https://example.com/module.js',
        'checksum': 'a' * 64,
        'downloadSizeBytes': 1024,
        'publishedAt': '2026-03-14T10:00:00Z',
      };

      expect(
        () => ModuleManifest.fromJson(json),
        throwsA(predicate((e) =>
            e is FormatException && e.message.contains('Missing required field: moduleId'))),
      );
    });

    test('Null value in required field throws FormatException', () {
      final json = {
        'moduleId': null,
        'version': '1.0.0',
        'requiredShellVersion': '^1.0.0',
        'signature': 'A' * 344,
        'downloadUrl': 'https://example.com/module.js',
        'checksum': 'a' * 64,
        'downloadSizeBytes': 1024,
        'publishedAt': '2026-03-14T10:00:00Z',
      };

      expect(
        () => ModuleManifest.fromJson(json),
        throwsA(predicate((e) =>
            e is FormatException && e.message.contains('Field moduleId cannot be null'))),
      );
    });

    test('Invalid moduleId format fails validation', () {
      final manifest = ModuleManifest(
        moduleId: 'Invalid-ID!', // Invalid characters
        version: '1.0.0',
        requiredShellVersion: '^1.0.0',
        signature: 'A' * 344,
        downloadUrl: 'https://example.com/module.js',
        checksum: 'a' * 64,
        downloadSizeBytes: 1024,
        publishedAt: DateTime.parse('2026-03-14T10:00:00Z'),
      );

      final result = manifest.validate();

      expect(result.isValid, false);
      expect(result.errors.any((e) => e.contains('moduleId must match pattern')), true);
    });

    test('Invalid version format fails validation', () {
      final manifest = ModuleManifest(
        moduleId: 'test-module',
        version: 'v1.2', // Invalid: no patch version
        requiredShellVersion: '^1.0.0',
        signature: 'A' * 344,
        downloadUrl: 'https://example.com/module.js',
        checksum: 'a' * 64,
        downloadSizeBytes: 1024,
        publishedAt: DateTime.parse('2026-03-14T10:00:00Z'),
      );

      final result = manifest.validate();

      expect(result.isValid, false);
      expect(result.errors.any((e) => e.contains('version must be valid semantic version')), true);
    });

    test('Invalid checksum length fails validation', () {
      final manifest = ModuleManifest(
        moduleId: 'test-module',
        version: '1.0.0',
        requiredShellVersion: '^1.0.0',
        signature: 'A' * 344,
        downloadUrl: 'https://example.com/module.js',
        checksum: 'a' * 32, // Wrong length
        downloadSizeBytes: 1024,
        publishedAt: DateTime.parse('2026-03-14T10:00:00Z'),
      );

      final result = manifest.validate();

      expect(result.isValid, false);
      expect(result.errors.any((e) => e.contains('checksum must be 64 hexadecimal characters')), true);
    });

    test('Non-HTTPS downloadUrl fails validation', () {
      final manifest = ModuleManifest(
        moduleId: 'test-module',
        version: '1.0.0',
        requiredShellVersion: '^1.0.0',
        signature: 'A' * 344,
        downloadUrl: 'http://example.com/module.js', // HTTP not HTTPS
        checksum: 'a' * 64,
        downloadSizeBytes: 1024,
        publishedAt: DateTime.parse('2026-03-14T10:00:00Z'),
      );

      final result = manifest.validate();

      expect(result.isValid, false);
      expect(result.errors.any((e) => e.contains('downloadUrl must use HTTPS scheme')), true);
    });

    test('Empty manifest JSON throws FormatException', () {
      expect(
        () => ModuleManifest.fromJson({}),
        throwsA(predicate((e) => e is FormatException)),
      );
    });

    test('Oversized module fails validation', () {
      final manifest = ModuleManifest(
        moduleId: 'test-module',
        version: '1.0.0',
        requiredShellVersion: '^1.0.0',
        signature: 'A' * 344,
        downloadUrl: 'https://example.com/module.js',
        checksum: 'a' * 64,
        downloadSizeBytes: 60000000, // > 50 MB
        publishedAt: DateTime.parse('2026-03-14T10:00:00Z'),
      );

      final result = manifest.validate();

      expect(result.isValid, false);
      expect(result.errors.any((e) => e.contains('downloadSizeBytes exceeds maximum')), true);
    });

    test('Future publishedAt generates warning', () {
      final future = DateTime.now().add(const Duration(days: 1));
      final manifest = ModuleManifest(
        moduleId: 'test-module',
        version: '1.0.0',
        requiredShellVersion: '^1.0.0',
        signature: 'A' * 344,
        downloadUrl: 'https://example.com/module.js',
        checksum: 'a' * 64,
        downloadSizeBytes: 1024,
        publishedAt: future,
      );

      final result = manifest.validate();

      expect(result.isValid, true); // Should still be valid
      expect(result.warnings.any((w) => w.contains('publishedAt is in the future')), true);
    });

    test('Unknown metadata fields are ignored', () {
      final json = {
        'moduleId': 'test-module',
        'version': '1.0.0',
        'requiredShellVersion': '^1.0.0',
        'signature': 'A' * 344,
        'downloadUrl': 'https://example.com/module.js',
        'checksum': 'a' * 64,
        'downloadSizeBytes': 1024,
        'publishedAt': '2026-03-14T10:00:00Z',
        'metadata': {
          'unknownField': 'value',
          'anotherUnknown': 123,
        },
      };

      // Should not throw
      final manifest = ModuleManifest.fromJson(json);
      final result = manifest.validate();

      expect(result.isValid, true);
      expect(manifest.metadata['unknownField'], 'value');
    });

    test('toJson round-trip preserves data', () {
      final original = ModuleManifest(
        moduleId: 'test-module',
        version: '1.0.0',
        requiredShellVersion: '^1.0.0',
        signature: 'A' * 344,
        downloadUrl: 'https://example.com/module.js',
        checksum: 'a' * 64,
        downloadSizeBytes: 1024,
        publishedAt: DateTime.parse('2026-03-14T10:00:00Z'),
        metadata: {'test': 'value'},
      );

      final json = original.toJson();
      final restored = ModuleManifest.fromJson(json);

      expect(restored.moduleId, original.moduleId);
      expect(restored.version, original.version);
      expect(restored.checksum, original.checksum);
    });
  });
}
