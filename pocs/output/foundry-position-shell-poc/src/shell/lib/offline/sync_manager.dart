// Phase 3: Sync Manager Service
// Purpose: Orchestrates automatic synchronization of offline transactions when network returns

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'offline_transaction_queue.dart';
import 'conflict_resolver.dart';
import 'local_transaction_cache.dart';
import '../network/network_monitor.dart';
import '../network/network_state.dart';
import '../config/app_config.dart';

class SyncResult {
  final int totalTransactions;
  final int syncedCount;
  final int failedCount;
  final int downloadedCount; // Phase 3: Downloaded from server
  final Duration duration;
  final List<SyncError> errors;

  SyncResult({
    required this.totalTransactions,
    required this.syncedCount,
    required this.failedCount,
    this.downloadedCount = 0,
    required this.duration,
    this.errors = const [],
  });
}

class SyncError {
  final String transactionId;
  final String error;

  SyncError({
    required this.transactionId,
    required this.error,
  });
}

class SyncProgress {
  final int total;
  final int current;
  final double percentComplete;

  SyncProgress({
    required this.total,
    required this.current,
  }) : percentComplete = total > 0 ? (current / total * 100) : 0;
}

class SyncManager {
  static final SyncManager instance = SyncManager._internal();
  factory SyncManager() => instance;
  SyncManager._internal();

  final OfflineTransactionQueue _queue = OfflineTransactionQueue.instance;
  final ConflictResolver _conflictResolver = ConflictResolver.instance;
  final LocalTransactionCache _cache = LocalTransactionCache.instance;
  final NetworkMonitor _networkMonitor = NetworkMonitor.instance;

  final StreamController<SyncProgress> _progressController = StreamController<SyncProgress>.broadcast();

  bool _isSyncing = false;
  bool _autoSyncEnabled = true;
  DateTime? _lastSyncTime;
  StreamSubscription? _networkSubscription;
  Database? _database;

  // Sync configuration
  static const int batchSize = 50;
  static const Duration batchTimeout = Duration(seconds: 30);
  static const String syncEndpoint = 'https://api.foundry.example.com/v1/sync/transactions';

  Stream<SyncProgress> get syncProgressStream => _progressController.stream;

  Future<void> initialize() async {
    // Listen to network state changes for auto-sync
    _networkSubscription = _networkMonitor.stateChanges.listen((state) {
      if (state == NetworkState.online && _autoSyncEnabled) {
        // Trigger auto-sync within 1 second of reconnect
        Future.delayed(const Duration(milliseconds: 500), () async {
          if (!_isSyncing) {
            print('[SyncManager] Network reconnected, triggering auto-sync');
            await syncNow();
          }
        });
      }
    });
  }

  Future<SyncResult> syncNow() async {
    // If sync already in progress, return existing operation result
    if (_isSyncing) {
      print('[SyncManager] Sync already in progress, waiting for completion');
      // Wait for current sync to complete
      while (_isSyncing) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      // Return last sync result (simplified)
      return SyncResult(
        totalTransactions: 0,
        syncedCount: 0,
        failedCount: 0,
        duration: Duration.zero,
      );
    }

    _isSyncing = true;
    final startTime = DateTime.now();

    int syncedCount = 0;
    int failedCount = 0;
    int downloadedCount = 0;
    final errors = <SyncError>[];

    try {
      // Check network connectivity
      final isOnline = await _networkMonitor.isOnline();
      if (!isOnline) {
        print('[SyncManager] Cannot sync: network offline');
        return SyncResult(
          totalTransactions: 0,
          syncedCount: 0,
          failedCount: 0,
          downloadedCount: 0,
          duration: DateTime.now().difference(startTime),
          errors: [SyncError(transactionId: 'network', error: 'Network offline')],
        );
      }

      // Phase 3 Full Offline: Bidirectional sync
      print('[SyncManager] Starting bidirectional sync');

      // STEP 1: Upload pending transactions (write queue)
      final pending = await _queue.getPendingTransactions();
      final totalTransactions = pending.length;

      if (totalTransactions > 0) {
        print('[SyncManager] Uploading $totalTransactions queued transactions');

        // Process in batches of 50
        for (int i = 0; i < pending.length; i += batchSize) {
          final batch = pending.skip(i).take(batchSize).toList();

          // Emit progress
          _progressController.add(SyncProgress(
            total: totalTransactions,
            current: i,
          ));

          // Sync batch
          final batchResult = await _syncBatch(batch);
          syncedCount += batchResult.syncedCount;
          failedCount += batchResult.failedCount;
          errors.addAll(batchResult.errors);

          // Check if network disconnected during sync
          if (!await _networkMonitor.isOnline()) {
            print('[SyncManager] Network disconnected during upload, pausing');
            break;
          }
        }

        print('[SyncManager] Upload complete: $syncedCount synced, $failedCount failed');
      } else {
        print('[SyncManager] No pending transactions to upload');
      }

      // STEP 2: Download new transactions from server (Phase 3 Full Offline)
      if (await _networkMonitor.isOnline()) {
        print('[SyncManager] Downloading new transactions from server');
        final downloadResult = await _downloadNewTransactions();
        downloadedCount = downloadResult.downloadedCount;
        errors.addAll(downloadResult.errors);
        print('[SyncManager] Downloaded $downloadedCount new transactions');
      }

      // Emit final progress
      _progressController.add(SyncProgress(
        total: totalTransactions,
        current: syncedCount + failedCount,
      ));

      _lastSyncTime = DateTime.now();

      // Update last sync timestamp
      await _updateSyncMetadata(
        'last_sync_timestamp',
        DateTime.now().millisecondsSinceEpoch.toString(),
      );

      await _updateSyncMetadata(
        'last_sync_status',
        'success',
      );

      // Record sync history
      await _recordSyncHistory(
        totalTransactions: totalTransactions,
        syncedCount: syncedCount,
        failedCount: failedCount,
        downloadedCount: downloadedCount,
        startTime: startTime,
      );

      print('[SyncManager] Bidirectional sync completed: $syncedCount uploaded, $downloadedCount downloaded, $failedCount failed');

      return SyncResult(
        totalTransactions: totalTransactions,
        syncedCount: syncedCount,
        failedCount: failedCount,
        downloadedCount: downloadedCount,
        duration: DateTime.now().difference(startTime),
        errors: errors,
      );
    } catch (e) {
      print('[SyncManager] Sync error: $e');

      await _updateSyncMetadata('last_sync_status', 'error');

      return SyncResult(
        totalTransactions: 0,
        syncedCount: syncedCount,
        failedCount: failedCount,
        downloadedCount: downloadedCount,
        duration: DateTime.now().difference(startTime),
        errors: [SyncError(transactionId: 'sync', error: e.toString())],
      );
    } finally {
      _isSyncing = false;
    }
  }

  Future<bool> isSyncing() async {
    return _isSyncing;
  }

  Future<DateTime?> getLastSyncTime() async {
    return _lastSyncTime;
  }

  Future<void> pauseAutoSync() async {
    _autoSyncEnabled = false;
    print('[SyncManager] Auto-sync paused');
  }

  Future<void> resumeAutoSync() async {
    _autoSyncEnabled = true;
    print('[SyncManager] Auto-sync resumed');
  }

  Future<void> dispose() async {
    await _networkSubscription?.cancel();
    await _progressController.close();
    await _database?.close();
    _database = null;
  }

  // Private: Sync a batch of transactions
  Future<SyncResult> _syncBatch(List<OfflineTransaction> batch) async {
    int syncedCount = 0;
    int failedCount = 0;
    final errors = <SyncError>[];

    try {
      // Prepare batch payload
      final batchPayload = {
        'transactions': batch.map((t) => {
          'transactionId': t.transactionId,
          'moduleId': t.moduleId,
          'timestamp': t.timestamp,
          'payload': json.decode(t.payload),
        }).toList(),
      };

      // POC mode: Mock sync endpoint
      if (syncEndpoint.contains('example.com')) {
        print('[SyncManager] POC mode: Simulating batch sync for ${batch.length} transactions');

        // Simulate network delay
        await Future.delayed(const Duration(milliseconds: 500));

        // Mock successful sync
        for (final transaction in batch) {
          await _queue.markSynced(transaction.transactionId);
          syncedCount++;
        }

        return SyncResult(
          totalTransactions: batch.length,
          syncedCount: syncedCount,
          failedCount: 0,
          duration: const Duration(milliseconds: 500),
        );
      }

      // Real HTTP sync (not used in POC)
      final response = await http.post(
        Uri.parse(syncEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(batchPayload),
      ).timeout(batchTimeout);

      if (response.statusCode == 200) {
        // Success
        for (final transaction in batch) {
          await _queue.markSynced(transaction.transactionId);
          syncedCount++;
        }
      } else if (response.statusCode == 409) {
        // Conflict - apply conflict resolution
        final responseData = json.decode(response.body) as Map<String, dynamic>;
        final conflicts = responseData['conflicts'] as List<dynamic>? ?? [];

        for (final transaction in batch) {
          final conflict = conflicts.firstWhere(
            (c) => c['transactionId'] == transaction.transactionId,
            orElse: () => null,
          );

          if (conflict != null) {
            // Resolve conflict
            final serverTransaction = ServerTransaction(
              transactionId: conflict['transactionId'] as String,
              timestamp: conflict['timestamp'] as int,
              data: conflict['data'] as Map<String, dynamic>,
            );

            final resolution = await _conflictResolver.resolve(transaction, serverTransaction);

            if (resolution.winner == TransactionSource.local) {
              // Retry with local data
              await _queue.markFailed(transaction.transactionId, 'Conflict, local wins, retry needed');
              failedCount++;
            } else {
              // Remote wins, mark as synced
              await _queue.markSynced(transaction.transactionId);
              syncedCount++;
            }
          } else {
            await _queue.markSynced(transaction.transactionId);
            syncedCount++;
          }
        }
      } else {
        // Server error
        for (final transaction in batch) {
          await _queue.markFailed(transaction.transactionId, 'HTTP ${response.statusCode}');
          failedCount++;
          errors.add(SyncError(
            transactionId: transaction.transactionId,
            error: 'HTTP ${response.statusCode}',
          ));
        }
      }
    } catch (e) {
      // Network error or timeout
      for (final transaction in batch) {
        await _queue.markFailed(transaction.transactionId, e.toString());
        failedCount++;
        errors.add(SyncError(
          transactionId: transaction.transactionId,
          error: e.toString(),
        ));
      }
    }

    return SyncResult(
      totalTransactions: batch.length,
      syncedCount: syncedCount,
      failedCount: failedCount,
      duration: Duration.zero,
      errors: errors,
    );
  }

  // Private: Download new transactions from server (Phase 3 Full Offline)
  Future<({int downloadedCount, List<SyncError> errors})> _downloadNewTransactions() async {
    int downloadedCount = 0;
    final errors = <SyncError>[];

    try {
      // Get last sync timestamp
      final lastSyncTimestamp = await _getLastSyncTimestamp();

      print('[SyncManager] Fetching transactions since timestamp: $lastSyncTimestamp');

      // FIXED: Use centralized backend configuration from AppConfig
      final downloadUrl = '${AppConfig.transactionsUrl}?limit=100&offset=0';

      print('[SyncManager] Downloading from: $downloadUrl');

      final response = await http.get(
        Uri.parse(downloadUrl),
        headers: {'Content-Type': 'application/json'},
      ).timeout(batchTimeout);

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body) as Map<String, dynamic>;
        final transactions = responseData['transactions'] as List<dynamic>? ?? [];

        print('[SyncManager] Backend returned ${transactions.length} transactions');

        if (transactions.isNotEmpty) {
          // Convert to CachedTransaction and upsert to cache
          final cachedTransactions = transactions.map((txJson) {
            return CachedTransaction.fromApiJson(txJson as Map<String, dynamic>);
          }).toList();

          await _cache.upsertBatch(cachedTransactions);

          downloadedCount = cachedTransactions.length;
          print('[SyncManager] Downloaded and cached $downloadedCount transactions');
        } else {
          print('[SyncManager] No transactions on server (empty database)');
        }
      } else {
        print('[SyncManager] HTTP error ${response.statusCode}: ${response.body}');
        errors.add(SyncError(
          transactionId: 'download',
          error: 'HTTP ${response.statusCode}: ${response.body}',
        ));
      }
    } catch (e) {
      print('[SyncManager] Download error: $e');
      errors.add(SyncError(
        transactionId: 'download',
        error: e.toString(),
      ));
    }

    return (downloadedCount: downloadedCount, errors: errors);
  }

  // Private: Get last sync timestamp from metadata
  Future<int> _getLastSyncTimestamp() async {
    try {
      final db = await _getDatabase();

      final results = await db.query(
        'sync_metadata',
        columns: ['value'],
        where: 'key = ?',
        whereArgs: ['last_sync_timestamp'],
        limit: 1,
      );

      if (results.isEmpty) return 0;

      return int.tryParse(results.first['value'] as String) ?? 0;
    } catch (e) {
      print('[SyncManager] Failed to get last sync timestamp: $e');
      return 0;
    }
  }

  // Private: Update sync metadata
  Future<void> _updateSyncMetadata(String key, String value) async {
    try {
      final db = await _getDatabase();

      await db.insert(
        'sync_metadata',
        {
          'key': key,
          'value': value,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      print('[SyncManager] Failed to update sync metadata ($key): $e');
    }
  }

  // Public: Get sync status for UI
  Future<Map<String, dynamic>> getSyncStatus() async {
    try {
      final pendingCount = await _queue.getPendingCount();
      final cacheStats = await _cache.getStats();

      final lastSyncTimestamp = await _getLastSyncTimestamp();
      final lastSyncTime = lastSyncTimestamp > 0
          ? DateTime.fromMillisecondsSinceEpoch(lastSyncTimestamp)
          : null;

      return {
        'isSyncing': _isSyncing,
        'lastSyncTime': lastSyncTime?.toIso8601String(),
        'pendingUploadCount': pendingCount,
        'cacheCount': cacheStats.totalCount,
        'cacheSizeBytes': cacheStats.cacheSizeBytes,
        'cacheOldestTimestamp': cacheStats.oldestTimestamp,
        'cacheNewestTimestamp': cacheStats.newestTimestamp,
      };
    } catch (e) {
      print('[SyncManager] Failed to get sync status: $e');
      return {
        'error': e.toString(),
      };
    }
  }

  // Private: Record sync history to database
  Future<void> _recordSyncHistory({
    required int totalTransactions,
    required int syncedCount,
    required int failedCount,
    required int downloadedCount,
    required DateTime startTime,
  }) async {
    try {
      final db = await _getDatabase();

      await db.insert('sync_history', {
        'started_at': startTime.millisecondsSinceEpoch,
        'completed_at': DateTime.now().millisecondsSinceEpoch,
        'total_transactions': totalTransactions,
        'synced_count': syncedCount,
        'failed_count': failedCount,
        'downloaded_count': downloadedCount,
        'error': null,
      });
    } catch (e) {
      print('[SyncManager] Failed to record sync history: $e');
    }
  }

  // Private: Get database instance
  Future<Database> _getDatabase() async {
    if (_database != null) return _database!;

    final appDir = await getApplicationSupportDirectory();
    final dbPath = path.join(appDir.path, 'offline_transactions.db');

    _database = await openDatabase(dbPath);
    return _database!;
  }
}
