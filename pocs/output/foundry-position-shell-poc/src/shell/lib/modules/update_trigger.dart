// Phase 3: Update Trigger Component
// Purpose: Listens to network reconnect and position switch events, triggers update checks

import 'dart:async';
import '../network/network_monitor.dart';
import '../network/network_state.dart';
import 'update_scheduler.dart';

class UpdateTrigger {
  static final UpdateTrigger instance = UpdateTrigger._internal();
  factory UpdateTrigger() => instance;
  UpdateTrigger._internal();

  final UpdateScheduler _scheduler = UpdateScheduler.instance;

  StreamSubscription? _networkSubscription;
  DateTime? _lastUpdateCheckTime;

  // Debounce: minimum 60 seconds between update checks
  static const Duration _debounceDuration = Duration(seconds: 60);

  Future<void> initialize(NetworkMonitor networkMonitor) async {
    print('[UpdateTrigger] Initializing update triggers');

    // Listen to network state changes
    _networkSubscription = networkMonitor.stateChanges.listen((state) async {
      if (state == NetworkState.online) {
        // Network reconnected, trigger update check
        await _triggerUpdateCheck('network_reconnect');
      }
    });
  }

  Future<void> onPositionSwitch(String newPositionId) async {
    print('[UpdateTrigger] Position switch detected: $newPositionId');

    // Check if network is online before triggering update
    final networkMonitor = NetworkMonitor.instance;
    final isOnline = await networkMonitor.isOnline();

    if (isOnline) {
      await _triggerUpdateCheck('position_switch');
    } else {
      print('[UpdateTrigger] Skipping update check: network offline');
    }
  }

  Future<void> dispose() async {
    await _networkSubscription?.cancel();
    _networkSubscription = null;
  }

  // Private: Trigger update check with debouncing
  Future<void> _triggerUpdateCheck(String reason) async {
    final now = DateTime.now();

    // Check debounce
    if (_lastUpdateCheckTime != null) {
      final timeSinceLastCheck = now.difference(_lastUpdateCheckTime!);
      if (timeSinceLastCheck < _debounceDuration) {
        print('[UpdateTrigger] Update check debounced (${timeSinceLastCheck.inSeconds}s since last check)');
        return;
      }
    }

    print('[UpdateTrigger] Triggering update check: $reason');
    _lastUpdateCheckTime = now;

    await _scheduler.checkNow();
  }
}
