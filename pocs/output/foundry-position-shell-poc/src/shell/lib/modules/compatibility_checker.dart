// D4.1: Compatibility Checker Service
// Purpose: Validate module compatibility with shell version

import 'package:pub_semver/pub_semver.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:io';

class CompatibilityChecker {
  // Hardcoded shell version from pubspec.yaml
  static const String _shellVersion = '1.0.0';

  // Check if module version is compatible with current shell version
  Future<CompatibilityResult> checkCompatibility({
    required String moduleId,
    required String moduleVersion,
    required String requiredShellVersion,
  }) async {
    try {
      final shellVer = getCurrentShellVersion();

      // Parse shell version
      final Version currentVersion;
      try {
        currentVersion = Version.parse(shellVer);
      } catch (e) {
        throw StateError('Invalid shell version');
      }

      // Parse version range
      final VersionRange range;
      try {
        range = parseVersionRange(requiredShellVersion);
      } catch (e) {
        return CompatibilityResult(
          isCompatible: false,
          shellVersion: shellVer,
          requiredShellVersion: requiredShellVersion,
          incompatibilityReason: 'Invalid version range syntax',
        );
      }

      // Check if current version is in range
      final isCompatible = range.allows(shellVer);

      if (!isCompatible) {
        String reason;
        if (Version.parse(range.min).compareTo(currentVersion) > 0) {
          reason = 'Requires shell version ${range.min}, current version is $shellVer';
        } else {
          reason = 'Module requires shell ${requiredShellVersion}, current version is $shellVer';
        }

        return CompatibilityResult(
          isCompatible: false,
          shellVersion: shellVer,
          requiredShellVersion: requiredShellVersion,
          incompatibilityReason: reason,
        );
      }

      // Check for warnings
      final warnings = <String>[];

      // Warn if shell is much newer (>1 major version ahead)
      final minVersion = Version.parse(range.min);
      if (currentVersion.major > minVersion.major + 1) {
        warnings.add('Shell version is much newer than module was tested with');
      }

      return CompatibilityResult(
        isCompatible: true,
        shellVersion: shellVer,
        requiredShellVersion: requiredShellVersion,
        warnings: warnings,
      );
    } catch (e) {
      if (e is StateError) rethrow;
      return CompatibilityResult(
        isCompatible: false,
        shellVersion: getCurrentShellVersion(),
        requiredShellVersion: requiredShellVersion,
        incompatibilityReason: e.toString(),
      );
    }
  }

  // Get current shell version
  String getCurrentShellVersion() {
    return _shellVersion;
  }

  // Parse and validate semantic version range
  VersionRange parseVersionRange(String rangeString) {
    try {
      // Handle caret range: ^1.2.3
      if (rangeString.startsWith('^')) {
        final versionStr = rangeString.substring(1);
        final version = Version.parse(versionStr);

        // Special handling for major version 0
        if (version.major == 0) {
          // ^0.1.2 -> >=0.1.2 <0.2.0
          return VersionRange(
            min: versionStr,
            max: '${version.major}.${version.minor + 1}.0',
            includeMax: false,
          );
        }

        // ^1.2.3 -> >=1.2.3 <2.0.0
        return VersionRange(
          min: versionStr,
          max: '${version.major + 1}.0.0',
          includeMax: false,
        );
      }

      // Handle tilde range: ~1.2.3
      if (rangeString.startsWith('~')) {
        final versionStr = rangeString.substring(1);
        final version = Version.parse(versionStr);

        // ~1.2.3 -> >=1.2.3 <1.3.0
        return VersionRange(
          min: versionStr,
          max: '${version.major}.${version.minor + 1}.0',
          includeMax: false,
        );
      }

      // Handle >= range: >=1.2.3
      if (rangeString.startsWith('>=')) {
        final versionStr = rangeString.substring(2).trim();
        Version.parse(versionStr); // Validate
        return VersionRange(
          min: versionStr,
          max: '999.999.999',
          includeMax: true,
        );
      }

      // Handle explicit range: >=1.2.0 <2.0.0
      if (rangeString.contains(' ')) {
        final parts = rangeString.split(' ');
        if (parts.length >= 2) {
          final minPart = parts[0];
          final maxPart = parts[1];

          String min, max;
          bool includeMax = false;

          if (minPart.startsWith('>=')) {
            min = minPart.substring(2).trim();
          } else {
            throw FormatException('Invalid range format');
          }

          if (maxPart.startsWith('<')) {
            max = maxPart.substring(1).trim();
            includeMax = false;
          } else if (maxPart.startsWith('<=')) {
            max = maxPart.substring(2).trim();
            includeMax = true;
          } else {
            throw FormatException('Invalid range format');
          }

          Version.parse(min); // Validate
          Version.parse(max); // Validate

          return VersionRange(
            min: min,
            max: max,
            includeMax: includeMax,
          );
        }
      }

      // Handle exact version: 1.2.3
      final version = Version.parse(rangeString);
      return VersionRange(
        min: rangeString,
        max: rangeString,
        includeMax: true,
      );
    } catch (e) {
      throw FormatException('Invalid version range: $e');
    }
  }
}

class CompatibilityResult {
  final bool isCompatible;
  final String shellVersion;
  final String requiredShellVersion;
  final String? incompatibilityReason;
  final List<String> warnings;

  CompatibilityResult({
    required this.isCompatible,
    required this.shellVersion,
    required this.requiredShellVersion,
    this.incompatibilityReason,
    this.warnings = const [],
  });
}

class VersionRange {
  final String min;
  final String max;
  final bool includeMax;

  VersionRange({
    required this.min,
    required this.max,
    this.includeMax = false,
  });

  bool allows(String versionStr) {
    try {
      final version = Version.parse(versionStr);
      final minVersion = Version.parse(min);
      final maxVersion = Version.parse(max);

      if (version.compareTo(minVersion) < 0) return false;

      if (includeMax) {
        return version.compareTo(maxVersion) <= 0;
      } else {
        return version.compareTo(maxVersion) < 0;
      }
    } catch (e) {
      return false;
    }
  }
}
