// Phase 3: Offline Transaction Queue Service
// Purpose: Persists offline user actions to SQLite database for later sync

import 'dart:async';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import '../database/offline_schema.dart';

enum SyncStatus {
  pending,  // 0
  syncing,  // 1
  synced,   // 2
  failed    // 3
}

class OfflineTransaction {
  final String transactionId;
  final String moduleId;
  final int timestamp;
  final String payload;
  SyncStatus syncStatus;
  int retryCount;
  String? lastError;

  OfflineTransaction({
    required this.transactionId,
    required this.moduleId,
    required this.timestamp,
    required this.payload,
    this.syncStatus = SyncStatus.pending,
    this.retryCount = 0,
    this.lastError,
  });

  Map<String, dynamic> toDbMap() {
    return {
      'transaction_id': transactionId,
      'module_id': moduleId,
      'timestamp': timestamp,
      'payload': payload,
      'sync_status': syncStatus.index,
      'retry_count': retryCount,
      'last_error': lastError,
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    };
  }

  factory OfflineTransaction.fromDbMap(Map<String, dynamic> map) {
    return OfflineTransaction(
      transactionId: map['transaction_id'] as String,
      moduleId: map['module_id'] as String,
      timestamp: map['timestamp'] as int,
      payload: map['payload'] as String,
      syncStatus: SyncStatus.values[map['sync_status'] as int],
      retryCount: map['retry_count'] as int,
      lastError: map['last_error'] as String?,
    );
  }
}

class SyncEvent {
  final String type; // 'started', 'progress', 'completed', 'error'
  final int? totalTransactions;
  final int? syncedCount;
  final int? failedCount;
  final String? error;

  SyncEvent({
    required this.type,
    this.totalTransactions,
    this.syncedCount,
    this.failedCount,
    this.error,
  });
}

class QueueFullException implements Exception {
  final String message;
  QueueFullException(this.message);

  @override
  String toString() => message;
}

class PayloadTooLargeException implements Exception {
  final String message;
  PayloadTooLargeException(this.message);

  @override
  String toString() => message;
}

class OfflineTransactionQueue {
  static final OfflineTransactionQueue instance = OfflineTransactionQueue._internal();
  factory OfflineTransactionQueue() => instance;
  OfflineTransactionQueue._internal();

  Database? _database;
  final StreamController<SyncEvent> _syncEventController = StreamController<SyncEvent>.broadcast();

  // Queue constraints
  static const int maxQueueSize = 1000;
  static const int warningThreshold = 900;
  static const int maxPayloadSize = 1024 * 1024; // 1 MB

  Stream<SyncEvent> get syncEventStream => _syncEventController.stream;

  Future<void> enqueue(OfflineTransaction transaction) async {
    // Check payload size
    if (transaction.payload.length > maxPayloadSize) {
      throw PayloadTooLargeException('Transaction payload exceeds 1MB limit');
    }

    // Check queue size
    final currentCount = await getPendingCount();
    if (currentCount >= maxQueueSize) {
      throw QueueFullException('Offline queue full. Sync required.');
    }

    // Warn if approaching limit
    if (currentCount >= warningThreshold) {
      print('[OfflineTransactionQueue] WARNING: Queue approaching limit ($currentCount/$maxQueueSize)');
      _syncEventController.add(SyncEvent(
        type: 'warning',
        totalTransactions: currentCount,
      ));
    }

    final db = await _getDatabase();

    // Atomic write using database transaction
    await db.transaction((txn) async {
      await txn.insert(
        'offline_transactions',
        transaction.toDbMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });

    print('[OfflineTransactionQueue] Transaction enqueued: ${transaction.transactionId}');
  }

  Future<List<OfflineTransaction>> getPendingTransactions() async {
    final db = await _getDatabase();

    final results = await db.query(
      'offline_transactions',
      where: 'sync_status = ?',
      whereArgs: [SyncStatus.pending.index],
      orderBy: 'timestamp ASC',
    );

    return results.map((map) => OfflineTransaction.fromDbMap(map)).toList();
  }

  Future<int> getPendingCount() async {
    final db = await _getDatabase();

    final result = await db.rawQuery('''
      SELECT COUNT(*) as count
      FROM offline_transactions
      WHERE sync_status IN (?, ?)
    ''', [SyncStatus.pending.index, SyncStatus.syncing.index]);

    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> markSynced(String transactionId) async {
    final db = await _getDatabase();

    await db.update(
      'offline_transactions',
      {
        'sync_status': SyncStatus.synced.index,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'transaction_id = ?',
      whereArgs: [transactionId],
    );

    print('[OfflineTransactionQueue] Transaction synced: $transactionId');
  }

  Future<void> markFailed(String transactionId, String error) async {
    final db = await _getDatabase();

    // Get current transaction
    final results = await db.query(
      'offline_transactions',
      where: 'transaction_id = ?',
      whereArgs: [transactionId],
    );

    if (results.isEmpty) return;

    final transaction = OfflineTransaction.fromDbMap(results.first);
    transaction.retryCount++;
    transaction.lastError = error;

    // If retry count >= 3, mark as failed, otherwise keep as pending
    if (transaction.retryCount >= 3) {
      transaction.syncStatus = SyncStatus.failed;
      print('[OfflineTransactionQueue] Transaction failed after 3 retries: $transactionId');
    } else {
      transaction.syncStatus = SyncStatus.pending;
      print('[OfflineTransactionQueue] Transaction retry ${transaction.retryCount}: $transactionId');
    }

    await db.update(
      'offline_transactions',
      {
        'sync_status': transaction.syncStatus.index,
        'retry_count': transaction.retryCount,
        'last_error': transaction.lastError,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'transaction_id = ?',
      whereArgs: [transactionId],
    );
  }

  Future<void> dispose() async {
    await _syncEventController.close();
    await _database?.close();
    _database = null;
  }

  // Private: Get database instance
  Future<Database> _getDatabase() async {
    if (_database != null) return _database!;

    final appDir = await getApplicationSupportDirectory();
    final dbPath = path.join(appDir.path, 'offline_transactions.db');

    try {
      _database = await openDatabase(
        dbPath,
        version: OfflineSchema.schemaVersion,
        onCreate: (db, version) async {
          await OfflineSchema.createSchema(db, version);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          await OfflineSchema.migrate(db, oldVersion, newVersion);
        },
      );

      return _database!;
    } catch (e) {
      // Database corruption recovery
      print('[OfflineTransactionQueue] Database error, attempting recovery: $e');

      // Try to delete corrupted database and create new one
      try {
        await deleteDatabase(dbPath);
        _database = await openDatabase(
          dbPath,
          version: OfflineSchema.schemaVersion,
          onCreate: (db, version) async {
            await OfflineSchema.createSchema(db, version);
          },
        );

        print('[OfflineTransactionQueue] Database recreated after corruption (data loss occurred)');
        return _database!;
      } catch (recoveryError) {
        throw StateError('Failed to initialize offline database: $recoveryError');
      }
    }
  }
}
