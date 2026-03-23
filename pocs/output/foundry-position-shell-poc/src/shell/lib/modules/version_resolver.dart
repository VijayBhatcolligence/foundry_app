// D4.2: Version Resolver Service
// Purpose: Select best compatible version from available options

import 'package:pub_semver/pub_semver.dart';

class VersionResolver {
  // Select best compatible version from list of available versions
  Future<VersionResolutionResult> resolveBestVersion({
    required String moduleId,
    required List<String> availableVersions,
    required String shellVersion,
  }) async {
    if (moduleId.isEmpty) {
      throw ArgumentError('moduleId required');
    }

    // Validate shell version
    try {
      Version.parse(shellVersion);
    } catch (e) {
      throw ArgumentError('Invalid shell version');
    }

    if (availableVersions.isEmpty) {
      return VersionResolutionResult(
        selectedVersion: null,
        reason: 'No versions available',
      );
    }

    // Parse and filter valid versions
    final validVersions = <String>[];
    final warnings = <String>[];

    for (final versionStr in availableVersions) {
      try {
        final version = Version.parse(versionStr);

        // Skip pre-release versions
        if (version.preRelease.isNotEmpty) {
          warnings.add('Skipping pre-release version: $versionStr');
          continue;
        }

        validVersions.add(versionStr);
      } catch (e) {
        warnings.add('Invalid version format: $versionStr');
      }
    }

    if (validVersions.isEmpty) {
      return VersionResolutionResult(
        selectedVersion: null,
        reason: 'No valid versions found',
        warnings: warnings,
      );
    }

    // Sort versions descending (newest first)
    validVersions.sort((a, b) => compareVersions(b, a));

    // For Phase 2, we select the highest version
    // In production, would filter by shell compatibility
    final selectedVersion = validVersions.first;

    return VersionResolutionResult(
      selectedVersion: selectedVersion,
      reason: 'Selected highest version',
      compatibleVersions: validVersions,
      warnings: warnings,
    );
  }

  // Compare two semantic versions (-1 if v1 < v2, 0 if equal, 1 if v1 > v2)
  int compareVersions(String version1, String version2) {
    try {
      final v1 = Version.parse(version1);
      final v2 = Version.parse(version2);
      return v1.compareTo(v2);
    } catch (e) {
      // If parsing fails, treat as equal
      return 0;
    }
  }

  // Check if upgrade from oldVersion to newVersion is safe
  bool isSafeUpgrade(String oldVersion, String newVersion) {
    try {
      final oldVer = Version.parse(oldVersion);
      final newVer = Version.parse(newVersion);

      // Downgrade is not safe
      if (newVer.compareTo(oldVer) < 0) {
        return false;
      }

      // Same version is safe
      if (newVer.compareTo(oldVer) == 0) {
        return true;
      }

      // Major version change is not safe
      if (newVer.major != oldVer.major) {
        return false;
      }

      // Minor or patch upgrade is safe
      return true;
    } catch (e) {
      return false;
    }
  }
}

class VersionResolutionResult {
  final String? selectedVersion;
  final String? reason;
  final List<String> compatibleVersions;
  final List<String> warnings;

  VersionResolutionResult({
    this.selectedVersion,
    this.reason,
    this.compatibleVersions = const [],
    this.warnings = const [],
  });
}
