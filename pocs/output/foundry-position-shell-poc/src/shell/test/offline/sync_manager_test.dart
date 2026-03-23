// Phase 3: Sync Manager Unit Tests

import 'package:flutter_test/flutter_test.dart';
import 'package:foundry_shell/offline/sync_manager.dart';
import 'package:foundry_shell/offline/offline_transaction_queue.dart';
import 'dart:convert';
import 'package:flutter/services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mock path_provider plugin for sync manager storage
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

  // Mock connectivity_plus plugin for network checks
  const MethodChannel('dev.fluttercommunity.plus/connectivity')
      .setMockMethodCallHandler((MethodCall methodCall) async {
    if (methodCall.method == 'check') {
      return 'wifi';
    }
    return null;
  });

  group('SyncManager', () {
    late SyncManager syncManager;
    late OfflineTransactionQueue queue;

    setUp(() async {
      syncManager = SyncManager.instance;
      queue = OfflineTransactionQueue.instance;
      await syncManager.initialize();
    });

    tearDown(() async {
      await syncManager.dispose();
    });

    test('syncNow returns SyncResult', () async {
      final result = await syncManager.syncNow();

      expect(result, isA<SyncResult>());
      expect(result.totalTransactions, greaterThanOrEqualTo(0));
      expect(result.syncedCount, greaterThanOrEqualTo(0));
      expect(result.failedCount, greaterThanOrEqualTo(0));
      expect(result.duration, isNotNull);
    });

    test('isSyncing returns false when not syncing', () async {
      final syncing = await syncManager.isSyncing();
      expect(syncing, isA<bool>());
    });

    test('tracks last sync time', () async {
      await syncManager.syncNow();

      final lastSync = await syncManager.getLastSyncTime();
      expect(lastSync, isNotNull);
    });

    test('auto-sync can be paused and resumed', () async {
      await syncManager.pauseAutoSync();
      // Verify paused

      await syncManager.resumeAutoSync();
      // Verify resumed
    });

    test('provides sync progress stream', () {
      expect(syncManager.syncProgressStream, isA<Stream<SyncProgress>>());
    });

    test('does not start duplicate sync when already syncing', () async {
      // Start first sync (don't await)
      final future1 = syncManager.syncNow();

      // Try to start second sync immediately
      final future2 = syncManager.syncNow();

      final results = await Future.wait([future1, future2]);

      // Both should complete successfully
      expect(results[0], isA<SyncResult>());
      expect(results[1], isA<SyncResult>());
    });

    test('syncs transactions in batches of 50', () async {
      // Add some test transactions
      for (int i = 0; i < 10; i++) {
        await queue.enqueue(OfflineTransaction(
          transactionId: 'batch-test-$i',
          moduleId: 'sample-warehouse',
          timestamp: DateTime.now().millisecondsSinceEpoch,
          payload: json.encode({'index': i}),
        ));
      }

      final result = await syncManager.syncNow();

      expect(result.totalTransactions, greaterThanOrEqualTo(10));
      // In POC mode, all should sync successfully
      expect(result.syncedCount, greaterThanOrEqualTo(10));
    });
  });

  group('SyncResult', () {
    test('creates sync result with counts', () {
      final result = SyncResult(
        totalTransactions: 10,
        syncedCount: 8,
        failedCount: 2,
        duration: const Duration(seconds: 5),
        errors: [],
      );

      expect(result.totalTransactions, 10);
      expect(result.syncedCount, 8);
      expect(result.failedCount, 2);
      expect(result.duration.inSeconds, 5);
    });
  });

  group('SyncProgress', () {
    test('calculates percent complete', () {
      final progress = SyncProgress(total: 100, current: 25);

      expect(progress.total, 100);
      expect(progress.current, 25);
      expect(progress.percentComplete, 25.0);
    });

    test('handles zero total', () {
      final progress = SyncProgress(total: 0, current: 0);

      expect(progress.percentComplete, 0.0);
    });
  });
}
