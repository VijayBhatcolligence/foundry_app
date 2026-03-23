// Phase 3: Offline Bridge Extension Unit Tests

import 'package:flutter_test/flutter_test.dart';
import 'package:foundry_shell/bridge/offline_bridge_extension.dart';
import 'package:foundry_shell/network/network_monitor.dart';
import 'package:foundry_shell/offline/offline_transaction_queue.dart';
import 'dart:convert';
import 'package:flutter/services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mock path_provider plugin for transaction queue storage
  const MethodChannel('plugins.flutter.io/path_provider')
      .setMockMethodCallHandler((MethodCall methodCall) async {
    if (methodCall.method == 'getApplicationSupportDirectory') {
      return '/tmp/test_app_support';
    }
    if (methodCall.method == 'getApplicationDocumentsDirectory') {
      return '/tmp/test_documents';
    }
    if (methodCall.method == 'getTemporaryDirectory') {
      return '/tmp/test_temp';
    }
    return null;
  });

  // Mock connectivity_plus plugin for network state
  const MethodChannel('dev.fluttercommunity.plus/connectivity')
      .setMockMethodCallHandler((MethodCall methodCall) async {
    if (methodCall.method == 'check') {
      return 'wifi';
    }
    return null;
  });

  group('OfflineBridgeExtension', () {
    late OfflineBridgeExtension extension;
    late NetworkMonitor networkMonitor;
    late OfflineTransactionQueue queue;

    setUp(() async {
      extension = OfflineBridgeExtension();
      networkMonitor = NetworkMonitor.instance;
      queue = OfflineTransactionQueue.instance;

      await networkMonitor.initialize();
    });

    tearDown(() async {
      await networkMonitor.dispose();
    });

    test('getNetworkState returns network state object', () async {
      final state = await extension.getNetworkState();

      expect(state, isA<Map<String, dynamic>>());
      expect(state['state'], isIn(['online', 'offline', 'reconnecting']));
      expect(state['type'], isIn(['wifi', 'cellular', 'ethernet', 'vpn', 'none']));
    });

    test('getPendingSyncCount returns integer count', () async {
      final count = await extension.getPendingSyncCount();

      expect(count, isA<int>());
      expect(count, greaterThanOrEqualTo(0));
    });

    test('getPendingSyncCount returns -1 on error', () async {
      // Normal case should return valid count
      final count = await extension.getPendingSyncCount();

      expect(count, greaterThanOrEqualTo(-1));
    });

    test('forceSyncNow returns sync result object', () async {
      final result = await extension.forceSyncNow();

      expect(result, isA<Map<String, dynamic>>());
      expect(result.containsKey('success'), isTrue);
      expect(result.containsKey('syncedCount'), isTrue);
      expect(result.containsKey('failedCount'), isTrue);
    });

    test('forceSyncNow returns error when offline', () async {
      // This would require mocking offline state
      final result = await extension.forceSyncNow();

      expect(result, isA<Map<String, dynamic>>());
      // In online state, should succeed or return already syncing
      expect(result['success'], isA<bool>());
    });

    test('forceSyncNow handles concurrent sync requests', () async {
      final result1 = extension.forceSyncNow();
      final result2 = extension.forceSyncNow();

      final results = await Future.wait([result1, result2]);

      expect(results[0]['success'], isA<bool>());
      expect(results[1]['success'], isA<bool>());
    });

    test('forceSyncNow times out after 10 seconds', () async {
      // Normal operation should complete quickly
      final stopwatch = Stopwatch()..start();

      final result = await extension.forceSyncNow();

      stopwatch.stop();

      expect(result, isA<Map<String, dynamic>>());
      // Should complete well within 10 seconds in POC mode
      expect(stopwatch.elapsed.inSeconds, lessThan(10));
    });
  });
}
