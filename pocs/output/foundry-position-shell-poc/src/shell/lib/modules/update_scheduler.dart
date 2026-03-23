// Phase 3: Update Scheduler Service
// Purpose: Runs periodic background checks for module updates every 4 hours

import 'dart:async';
import 'module_registry.dart';
import 'module_updater.dart';
import 'update_state_tracker.dart';

class UpdateScheduler {
  static final UpdateScheduler instance = UpdateScheduler._internal();
  factory UpdateScheduler() => instance;
  UpdateScheduler._internal();

  final ModuleRegistry _registry = ModuleRegistry.instance;
  final UpdateStateTracker _updateTracker = UpdateStateTracker.instance;

  Timer? _checkTimer;
  bool _isRunning = false;
  DateTime? _nextCheckTime;

  // Check interval: 4 hours
  final Duration checkInterval = const Duration(hours: 4);

  bool get isRunning => _isRunning;

  Future<void> start() async {
    if (_isRunning) {
      print('[UpdateScheduler] Already running');
      return;
    }

    _isRunning = true;
    print('[UpdateScheduler] Starting periodic update checks (every 4 hours)');

    // Calculate next check time
    _nextCheckTime = DateTime.now().add(checkInterval);

    // Start periodic timer
    _checkTimer = Timer.periodic(checkInterval, (timer) async {
      await _performUpdateCheck();
      _nextCheckTime = DateTime.now().add(checkInterval);
    });

    // Perform initial check
    await _performUpdateCheck();
  }

  Future<void> stop() async {
    _checkTimer?.cancel();
    _checkTimer = null;
    _isRunning = false;
    _nextCheckTime = null;
    print('[UpdateScheduler] Stopped');
  }

  Future<DateTime?> getNextCheckTime() async {
    return _nextCheckTime;
  }

  Future<void> checkNow() async {
    print('[UpdateScheduler] Manual update check triggered');
    await _performUpdateCheck();
  }

  Future<void> dispose() async {
    await stop();
  }

  // Private: Perform update check
  Future<void> _performUpdateCheck() async {
    try {
      print('[UpdateScheduler] Performing update check...');

      // Load latest registry (with mock URL for POC)
      final registryResult = await _registry.loadRegistry('mock://registry');

      if (!registryResult.success) {
        print('[UpdateScheduler] Registry load failed: ${registryResult.error}');
        return;
      }

      print('[UpdateScheduler] Registry loaded: ${registryResult.modulesLoaded} modules');

      // Check all modules for updates
      final updateResults = await _updateTracker.checkAllModulesForUpdates();

      final availableUpdates = updateResults.entries
          .where((e) => e.value.hasUpdate)
          .length;

      if (availableUpdates > 0) {
        print('[UpdateScheduler] $availableUpdates module updates available');
      } else {
        print('[UpdateScheduler] No updates available');
      }
    } catch (e) {
      print('[UpdateScheduler] Update check error: $e');
      // Don't fail the app, just log and continue
    }
  }
}
