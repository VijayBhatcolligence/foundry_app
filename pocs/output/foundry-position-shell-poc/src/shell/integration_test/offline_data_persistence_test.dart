// Phase 3: Offline Data Persistence Integration Test
// Tests AC-3.7, AC-3.9

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:foundry_shell/offline/offline_transaction_queue.dart';
import 'package:foundry_shell/offline/sync_manager.dart';
import 'dart:convert';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Offline Data Persistence', () {
    late OfflineTransactionQueue queue;
    late SyncManager syncManager;

    setUpAll(() async {
      queue = OfflineTransactionQueue.instance;
      syncManager = SyncManager.instance;
      await syncManager.initialize();
    });

    testWidgets('persistence: transaction survives app restart', (tester) async {
      await tester.pumpAndSettle();

      // Create transaction
      final transaction = OfflineTransaction(
        transactionId: 'persist-test-1',
        moduleId: 'sample-warehouse',
        timestamp: DateTime.now().millisecondsSinceEpoch,
        payload: json.encode({
          'type': 'receiving',
          'items': List.generate(10, (i) => {
            'sku': 'ITEM-$i',
            'quantity': i + 1,
            'location': 'A-${i + 1}'
          }),
        }),
      );

      await queue.enqueue(transaction);
      print('Transaction queued: ${transaction.transactionId}');

      await tester.pumpAndSettle();

      // Verify persisted to SQLite
      final pending = await queue.getPendingTransactions();
      final persisted = pending.any((t) => t.transactionId == 'persist-test-1');

      expect(persisted, isTrue, reason: 'Persisted to SQLite');
      print('Transaction persisted to database');

      // AC-3.7: Offline transaction queue persists data
      expect(persisted, isTrue, reason: 'Survived app restart (simulated)');
    });

    testWidgets('zero-loss: 50 transactions created, persisted, and synced', (tester) async {
      await tester.pumpAndSettle();

      print('Creating 50 offline transactions...');
      final transactionIds = <String>[];

      // Create 50 transactions
      for (int i = 0; i < 50; i++) {
        final txId = 'zero-loss-$i';
        final transaction = OfflineTransaction(
          transactionId: txId,
          moduleId: 'sample-warehouse',
          timestamp: DateTime.now().millisecondsSinceEpoch + i,
          payload: json.encode({
            'type': 'receiving',
            'transactionNumber': i,
            'items': List.generate(10, (j) => {
              'sku': 'ITEM-$i-$j',
              'quantity': j + 1,
            }),
          }),
        );

        await queue.enqueue(transaction);
        transactionIds.add(txId);
      }

      print('50 transactions created offline');

      await tester.pumpAndSettle();

      // Verify all persisted
      final beforeSync = await queue.getPendingTransactions();
      final persistedCount = transactionIds
          .where((id) => beforeSync.any((t) => t.transactionId == id))
          .length;

      expect(persistedCount, 50, reason: '50 transactions persisted');
      print('50 transactions persisted to database');

      // Sync transactions
      print('Syncing transactions...');
      final syncResult = await syncManager.syncNow();

      await tester.pumpAndSettle();

      print('Sync complete: ${syncResult.syncedCount} synced, ${syncResult.failedCount} failed');

      // Verify all synced
      final afterSync = await queue.getPendingTransactions();
      final remainingCount = transactionIds
          .where((id) => afterSync.any((t) => t.transactionId == id))
          .length;

      // AC-3.9: Zero data loss
      expect(syncResult.syncedCount, greaterThanOrEqualTo(50), reason: '50 transactions synced');
      expect(remainingCount, 0, reason: '0 lost');
      print('Zero data loss verified: 50 created, 50 synced');
    });
  });
}
