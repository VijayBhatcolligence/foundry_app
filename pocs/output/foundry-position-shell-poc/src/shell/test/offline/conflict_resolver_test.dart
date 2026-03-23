// Phase 3: Conflict Resolver Unit Tests

import 'package:flutter_test/flutter_test.dart';
import 'package:foundry_shell/offline/conflict_resolver.dart';
import 'package:foundry_shell/offline/offline_transaction_queue.dart';

void main() {
  group('ConflictResolver', () {
    late ConflictResolver resolver;

    setUp(() {
      resolver = ConflictResolver.instance;
    });

    test('local wins when local timestamp is newer', () async {
      final local = OfflineTransaction(
        transactionId: 'tx-1',
        moduleId: 'test',
        timestamp: 1000000,
        payload: '{"data": "local"}',
      );

      final remote = ServerTransaction(
        transactionId: 'tx-1',
        timestamp: 900000, // Older
        data: {'data': 'remote'},
      );

      final resolution = await resolver.resolve(local, remote);

      expect(resolution.winner, TransactionSource.local);
      expect(resolution.reason, contains('newer timestamp'));
    });

    test('remote wins when remote timestamp is newer', () async {
      final local = OfflineTransaction(
        transactionId: 'tx-2',
        moduleId: 'test',
        timestamp: 900000,
        payload: '{"data": "local"}',
      );

      final remote = ServerTransaction(
        transactionId: 'tx-2',
        timestamp: 1000000, // Newer
        data: {'data': 'remote'},
      );

      final resolution = await resolver.resolve(local, remote);

      expect(resolution.winner, TransactionSource.remote);
      expect(resolution.reason, contains('newer timestamp'));
    });

    test('remote wins when timestamps within tolerance', () async {
      final baseTime = DateTime.now().millisecondsSinceEpoch;

      final local = OfflineTransaction(
        transactionId: 'tx-3',
        moduleId: 'test',
        timestamp: baseTime,
        payload: '{"data": "local"}',
      );

      final remote = ServerTransaction(
        transactionId: 'tx-3',
        timestamp: baseTime + 500, // Within 1000ms tolerance
        data: {'data': 'remote'},
      );

      final resolution = await resolver.resolve(local, remote);

      expect(resolution.winner, TransactionSource.remote);
      expect(resolution.reason, contains('within tolerance'));
    });

    test('remote wins on large timestamp difference (clock skew)', () async {
      final local = OfflineTransaction(
        transactionId: 'tx-4',
        moduleId: 'test',
        timestamp: DateTime.now().millisecondsSinceEpoch,
        payload: '{"data": "local"}',
      );

      final remote = ServerTransaction(
        transactionId: 'tx-4',
        timestamp: DateTime.now().millisecondsSinceEpoch - (400 * 24 * 60 * 60 * 1000), // > 1 year
        data: {'data': 'remote'},
      );

      final resolution = await resolver.resolve(local, remote);

      expect(resolution.winner, TransactionSource.remote);
      expect(resolution.reason, contains('clock'));
    });

    test('handles deleted remote transaction', () async {
      final baseTime = DateTime.now().millisecondsSinceEpoch;

      final local = OfflineTransaction(
        transactionId: 'tx-5',
        moduleId: 'test',
        timestamp: baseTime + 10000, // After deletion
        payload: '{"data": "local"}',
      );

      final remote = ServerTransaction(
        transactionId: 'tx-5',
        timestamp: baseTime,
        data: {},
        deletedAt: baseTime + 5000,
      );

      final resolution = await resolver.resolve(local, remote);

      expect(resolution.winner, TransactionSource.local);
      expect(resolution.reason, contains('newer than remote deletion'));
    });

    test('keeps deleted when local older than deletion', () async {
      final baseTime = DateTime.now().millisecondsSinceEpoch;

      final local = OfflineTransaction(
        transactionId: 'tx-6',
        moduleId: 'test',
        timestamp: baseTime, // Before deletion
        payload: '{"data": "local"}',
      );

      final remote = ServerTransaction(
        transactionId: 'tx-6',
        timestamp: baseTime,
        data: {},
        deletedAt: baseTime + 5000,
      );

      final resolution = await resolver.resolve(local, remote);

      expect(resolution.winner, TransactionSource.remote);
      expect(resolution.reason, contains('deletion is authoritative'));
    });
  });

  group('ConflictResolution', () {
    test('creates resolution with winner and reason', () {
      final resolution = ConflictResolution(
        winner: TransactionSource.local,
        reason: 'Test reason',
      );

      expect(resolution.winner, TransactionSource.local);
      expect(resolution.reason, 'Test reason');
      expect(resolution.mergedData, isNull);
    });
  });
}
