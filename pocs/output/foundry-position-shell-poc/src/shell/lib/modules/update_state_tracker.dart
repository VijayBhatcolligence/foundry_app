// Phase 3: Update State Tracker Service
// Purpose: Track update check history and available updates
// Note: This service was missing from Phase 2 (spec gap)

import 'dart:async';
import 'package:pub_semver/pub_semver.dart';
import 'module_registry.dart';

class UpdateStateTracker {
  static final UpdateStateTracker instance = UpdateStateTracker._internal();
  factory UpdateStateTracker() => instance;
  UpdateStateTracker._internal();

  final ModuleRegistry _registry = ModuleRegistry.instance;

  DateTime? _lastCheckTime;
  final Map<String, UpdateCheckResult> _updateResults = {};

  // Check if update check should run (4 hour interval)
  bool shouldCheckForUpdates() {
    if (_lastCheckTime == null) return true;
    final elapsed = DateTime.now().difference(_lastCheckTime!);
    return elapsed.inHours >= 4;
  }

  // Mark that an update check was performed
  void markUpdateChecked() {
    _lastCheckTime = DateTime.now();
  }

  // Get last check time
  DateTime? getLastCheckTime() {
    return _lastCheckTime;
  }

  // Check all installed modules for updates
  Future<Map<String, UpdateCheckResult>> checkAllModulesForUpdates() async {
    markUpdateChecked();

    _updateResults.clear();

    // Get all available modules from registry
    final availableModules = await _registry.getAvailableModules();

    // Group by moduleId
    final moduleGroups = <String, List<ModuleMetadata>>{};
    for (final module in availableModules) {
      moduleGroups.putIfAbsent(module.moduleId, () => []).add(module);
    }

    // Check each module for updates
    for (final entry in moduleGroups.entries) {
      final moduleId = entry.key;

      // Get installed version
      final installedVersion = await _registry.getInstalledVersion(moduleId);

      if (installedVersion == null) {
        // Not installed, skip
        _updateResults[moduleId] = UpdateCheckResult(
          moduleId: moduleId,
          currentVersion: null,
          latestVersion: null,
          hasUpdate: false,
        );
        continue;
      }

      // Find latest version in registry
      final latestMetadata = await _registry.getLatestVersion(moduleId);

      if (latestMetadata == null) {
        // Module not in registry anymore
        _updateResults[moduleId] = UpdateCheckResult(
          moduleId: moduleId,
          currentVersion: installedVersion,
          latestVersion: null,
          hasUpdate: false,
        );
        continue;
      }

      // Compare versions using semver
      int comparison = 0;
      try {
        final installedVer = Version.parse(installedVersion);
        final latestVer = Version.parse(latestMetadata.version);
        comparison = installedVer.compareTo(latestVer);
      } catch (e) {
        // If parsing fails, treat as equal
        comparison = 0;
      }

      _updateResults[moduleId] = UpdateCheckResult(
        moduleId: moduleId,
        currentVersion: installedVersion,
        latestVersion: latestMetadata.version,
        hasUpdate: comparison < 0, // Installed version is older
      );
    }

    return Map.from(_updateResults);
  }

  // Get update status for specific module
  UpdateCheckResult? getUpdateStatus(String moduleId) {
    return _updateResults[moduleId];
  }

  // Get all modules with available updates
  List<UpdateCheckResult> getModulesWithUpdates() {
    return _updateResults.values.where((r) => r.hasUpdate).toList();
  }
}

class UpdateCheckResult {
  final String moduleId;
  final String? currentVersion;
  final String? latestVersion;
  final bool hasUpdate;

  UpdateCheckResult({
    required this.moduleId,
    this.currentVersion,
    this.latestVersion,
    required this.hasUpdate,
  });
}
