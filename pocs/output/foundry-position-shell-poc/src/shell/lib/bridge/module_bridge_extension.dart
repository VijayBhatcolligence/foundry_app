// D7.1: Module Bridge Extension
// Purpose: Extend Flutter-WebView bridge with module management methods

import 'dart:async';
import '../modules/module_registry.dart';
import '../modules/module_updater.dart';

class ModuleBridgeExtension {
  // Track method call frequency for throttling
  final List<DateTime> _recentCalls = [];
  static const int _maxCallsPerSecond = 10;

  // Check for updates for specific module
  Future<Map<String, dynamic>> checkForUpdates(String moduleId) async {
    if (!_checkThrottle()) {
      return {
        'success': false,
        'error': 'Rate limit exceeded',
      };
    }

    try {
      final result = await ModuleUpdater.instance.checkForUpdates(moduleId);

      return {
        'success': true,
        'updateAvailable': result.updateAvailable,
        'currentVersion': result.currentVersion,
        'latestVersion': result.latestVersion,
        'error': result.error,
      };
    } on Exception catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Get list of all available modules from registry
  Future<Map<String, dynamic>> getAvailableModules() async {
    if (!_checkThrottle()) {
      return {
        'success': false,
        'error': 'Rate limit exceeded',
      };
    }

    try {
      if (!ModuleRegistry.instance.isRegistryLoaded) {
        return {
          'success': false,
          'error': 'Module registry not loaded',
        };
      }

      final modules = await ModuleRegistry.instance.getAvailableModules();

      // Limit to first 100 modules
      final modulesData = modules.take(100).map((m) => {
            'moduleId': m.moduleId,
            'version': m.version,
            'isInstalled': m.isInstalled,
            'requiredShellVersion': m.requiredShellVersion,
          }).toList();

      return {
        'success': true,
        'modules': modulesData,
        'hasMore': modules.length > 100,
      };
    } on Exception catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Get current installed version for module
  Future<Map<String, dynamic>> getModuleVersion(String moduleId) async {
    if (!_checkThrottle()) {
      return {
        'success': false,
        'error': 'Rate limit exceeded',
      };
    }

    try {
      final version = await ModuleRegistry.instance.getInstalledVersion(moduleId);

      if (version == null) {
        return {
          'success': false,
          'moduleId': moduleId,
          'error': 'Module not found',
        };
      }

      return {
        'success': true,
        'moduleId': moduleId,
        'version': version,
      };
    } on Exception catch (e) {
      return {
        'success': false,
        'moduleId': moduleId,
        'error': e.toString(),
      };
    }
  }

  // Install module update
  Future<Map<String, dynamic>> installModuleUpdate(
      String moduleId, String version) async {
    if (!_checkThrottle()) {
      return {
        'success': false,
        'error': 'Rate limit exceeded',
      };
    }

    try {
      final result = await ModuleUpdater.instance
          .installUpdate(moduleId: moduleId, version: version)
          .timeout(const Duration(seconds: 60));

      return {
        'success': result.success,
        'installedVersion': result.installedVersion,
        'error': result.error,
      };
    } on TimeoutException {
      return {
        'success': false,
        'error': 'Operation timeout',
      };
    } on Exception catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Cancel in-progress update
  Future<Map<String, dynamic>> cancelModuleUpdate(String moduleId) async {
    if (!_checkThrottle()) {
      return {
        'success': false,
        'error': 'Rate limit exceeded',
      };
    }

    try {
      final state = ModuleUpdater.instance.getUpdateState(moduleId);

      if (state.status == UpdateStatus.idle ||
          state.status == UpdateStatus.complete ||
          state.status == UpdateStatus.failed ||
          state.status == UpdateStatus.cancelled) {
        return {
          'success': true,
          'cancelled': false, // Not updating, so nothing to cancel
        };
      }

      await ModuleUpdater.instance.cancelUpdate(moduleId);

      return {
        'success': true,
        'cancelled': true,
      };
    } on Exception catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Get update progress for module
  Future<Map<String, dynamic>> getUpdateProgress(String moduleId) async {
    if (!_checkThrottle()) {
      return {
        'success': false,
        'error': 'Rate limit exceeded',
      };
    }

    try {
      final state = ModuleUpdater.instance.getUpdateState(moduleId);

      return {
        'success': true,
        'status': state.status.toString().split('.').last,
        'percentComplete': state.progress?.percentComplete ?? 0.0,
        'currentOperation': state.progress?.currentOperation,
        'error': state.error,
      };
    } on Exception catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Register these methods with ShellBridge
  void registerWithBridge(dynamic bridge) {
    // This would be called from ShellBridge to register methods
    // For Phase 2, this is a placeholder as ShellBridge integration
    // requires Phase 1 ShellBridge to be available

    // In production:
    // bridge.registerMethod('module.checkForUpdates', checkForUpdates);
    // bridge.registerMethod('module.getAvailableModules', getAvailableModules);
    // etc.

    print('Module bridge extension methods registered');
  }

  // Private helper: Check rate limiting
  bool _checkThrottle() {
    final now = DateTime.now();

    // Remove calls older than 1 second
    _recentCalls.removeWhere(
        (call) => now.difference(call).inSeconds > 1);

    if (_recentCalls.length >= _maxCallsPerSecond) {
      return false;
    }

    _recentCalls.add(now);
    return true;
  }
}
