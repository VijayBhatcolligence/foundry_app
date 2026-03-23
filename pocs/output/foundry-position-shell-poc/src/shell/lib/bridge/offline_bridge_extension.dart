// Phase 3: Offline Bridge Extension
// Purpose: Extends RuntimeHostBridge with methods for position modules to query offline status

import 'dart:async';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import '../network/network_monitor.dart';
import '../offline/offline_transaction_queue.dart';
import '../offline/sync_manager.dart';
import '../offline/local_transaction_cache.dart';
import '../config/app_config.dart';

class OfflineBridgeExtension {
  final NetworkMonitor _networkMonitor = NetworkMonitor.instance;
  final OfflineTransactionQueue _queue = OfflineTransactionQueue.instance;
  final SyncManager _syncManager = SyncManager.instance;
  final LocalTransactionCache _cache = LocalTransactionCache.instance;
  final Uuid _uuid = const Uuid();

  // Backend configuration - now using centralized AppConfig
  static String get backendUrl => AppConfig.BACKEND_URL;

  /// Get current network state
  /// Returns: { "state": "online"|"offline"|"reconnecting", "type": "wifi"|"cellular"|"none" }
  Future<Map<String, dynamic>> getNetworkState() async {
    try {
      final state = _networkMonitor.currentState;
      final type = await _networkMonitor.getNetworkType();

      return {
        'state': state.name,
        'type': type.name,
      };
    } catch (e) {
      print('[OfflineBridgeExtension] Error getting network state: $e');
      return {
        'state': 'offline',
        'type': 'none',
        'error': e.toString(),
      };
    }
  }

  /// Get count of pending sync transactions
  /// Returns: count of transactions with syncStatus == pending
  /// Throws: Exception if queue is not initialized or count fails
  Future<int> getPendingSyncCount() async {
    return await _queue.getPendingCount();
    // Let exceptions propagate to caller - they should handle errors appropriately
  }

  /// Force sync now (user-triggered)
  /// Returns: { "success": bool, "syncedCount": int, "failedCount": int, "error": string? }
  Future<Map<String, dynamic>> forceSyncNow() async {
    try {
      // Check if already syncing
      final isSyncing = await _syncManager.isSyncing();
      if (isSyncing) {
        print('[OfflineBridgeExtension] Sync already in progress');
        // Return existing sync result
        return {
          'success': true,
          'syncedCount': 0,
          'failedCount': 0,
          'message': 'Sync already in progress',
        };
      }

      // Check network online
      final isOnline = await _networkMonitor.isOnline();
      if (!isOnline) {
        return {
          'success': false,
          'syncedCount': 0,
          'failedCount': 0,
          'error': 'Network offline',
        };
      }

      // Perform sync with 10 second timeout
      final syncResult = await _syncManager.syncNow()
          .timeout(const Duration(seconds: 10));

      return {
        'success': true,
        'syncedCount': syncResult.syncedCount,
        'failedCount': syncResult.failedCount,
        'error': syncResult.errors.isNotEmpty ? syncResult.errors.first.error : null,
      };
    } on TimeoutException {
      return {
        'success': false,
        'syncedCount': 0,
        'failedCount': 0,
        'error': 'Sync timeout after 10 seconds',
      };
    } catch (e) {
      print('[OfflineBridgeExtension] Error forcing sync: $e');
      return {
        'success': false,
        'syncedCount': 0,
        'failedCount': 0,
        'error': e.toString(),
      };
    }
  }

  /// Get transaction history (Cache-first: return cached data, sync in background)
  /// Returns: { success: bool, transactions: [...], fromCache: bool, lastSyncTime: string?, error?: string }
  Future<Map<String, dynamic>> getTransactionHistory() async {
    try {
      print('[OfflineBridgeExtension] Getting transaction history (cache-first)');

      // STEP 1: Get cached transactions immediately (fast UI)
      final cachedTransactions = await _cache.getRecent(days: 7);

      // Get sync status for UI
      final syncStatus = await _syncManager.getSyncStatus();

      // Convert to JSON format
      final transactionsJson = cachedTransactions.map((tx) => tx.toJson()).toList();

      print('[OfflineBridgeExtension] Returning ${cachedTransactions.length} cached transactions');

      // STEP 2: Trigger background sync (fetch new data from backend)
      // This will download transactions from the real backend and cache them
      // Don't wait for it, let it run in background
      _backgroundSync();

      return {
        'success': true,
        'transactions': transactionsJson,
        'fromCache': true,
        'cacheCount': cachedTransactions.length,
        'lastSyncTime': syncStatus['lastSyncTime'],
        'pendingUploadCount': syncStatus['pendingUploadCount'],
      };
    } catch (e) {
      print('[OfflineBridgeExtension] Error getting transaction history: $e');
      return {
        'success': false,
        'transactions': [],
        'error': e.toString(),
      };
    }
  }

  /// Get sync status for UI display
  /// Returns: { isSyncing: bool, lastSyncTime: string?, pendingUploadCount: int, cacheCount: int, ... }
  Future<Map<String, dynamic>> getSyncStatus() async {
    try {
      return await _syncManager.getSyncStatus();
    } catch (e) {
      print('[OfflineBridgeExtension] Error getting sync status: $e');
      return {
        'error': e.toString(),
      };
    }
  }

  /// Background sync (non-blocking)
  void _backgroundSync() {
    Future.delayed(Duration.zero, () async {
      try {
        final isOnline = await _networkMonitor.isOnline();
        if (isOnline && !await _syncManager.isSyncing()) {
          print('[OfflineBridgeExtension] Triggering background sync');
          await _syncManager.syncNow();
        }
      } catch (e) {
        print('[OfflineBridgeExtension] Background sync error: $e');
      }
    });
  }

  /// Submit transaction (Offline-first: cache locally + queue for sync + try backend if online)
  /// Params: { moduleId, poNumber, vendor, lineItems: [...] }
  /// Returns: { success: bool, transactionId: string, status: string, error?: string }
  Future<Map<String, dynamic>> submitTransaction(Map<String, dynamic> args) async {
    try {
      // Extract and validate parameters
      final moduleId = args['moduleId'] as String?;
      final poNumber = args['poNumber'] as String?;
      final vendor = args['vendor'] as String?;
      final lineItemsJson = args['lineItems'] as List<dynamic>?;

      if (moduleId == null || moduleId.isEmpty) {
        return {'success': false, 'error': 'moduleId is required'};
      }

      if (poNumber == null || poNumber.isEmpty) {
        return {'success': false, 'error': 'poNumber is required'};
      }

      if (vendor == null || vendor.isEmpty) {
        return {'success': false, 'error': 'vendor is required'};
      }

      if (lineItemsJson == null || lineItemsJson.isEmpty) {
        return {'success': false, 'error': 'lineItems are required'};
      }

      // Parse line items
      final lineItems = lineItemsJson.map((item) {
        return LineItem.fromJson(item as Map<String, dynamic>);
      }).toList();

      // Generate transaction ID
      final transactionId = 'TXN-${DateTime.now().millisecondsSinceEpoch}';
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      print('[OfflineBridgeExtension] Submitting transaction: $transactionId');

      // STEP 1: Cache locally immediately (optimistic UI)
      final cachedTransaction = CachedTransaction(
        transactionId: transactionId,
        poNumber: poNumber,
        vendor: vendor,
        lineItems: lineItems,
        createdAt: timestamp,
        status: 'local',
        cachedAt: timestamp,
        isDirty: true, // Mark as dirty (pending sync)
      );

      await _cache.upsert(cachedTransaction);

      print('[OfflineBridgeExtension] Transaction cached locally: $transactionId');

      // STEP 2: Try to submit to backend if online
      final isOnline = await _networkMonitor.isOnline();

      if (isOnline) {
        print('[OfflineBridgeExtension] Online: attempting backend submission');

        try {
          // Submit to backend
          final response = await http.post(
            Uri.parse('$backendUrl/api/transactions'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'transactionId': transactionId,
              'poNumber': poNumber,
              'vendor': vendor,
              'lineItems': lineItems.map((item) => item.toJson()).toList(),
              'createdAt': timestamp,
            }),
          ).timeout(const Duration(seconds: 5));

          if (response.statusCode == 201) {
            // Success: mark as synced
            await _cache.markSynced(transactionId);

            print('[OfflineBridgeExtension] Transaction submitted to backend successfully: $transactionId');

            return {
              'success': true,
              'transactionId': transactionId,
              'status': 'synced',
              'message': 'Transaction submitted successfully',
            };
          } else {
            // Backend error: queue for retry
            await _queueForSync(transactionId, moduleId, timestamp, cachedTransaction);

            return {
              'success': true,
              'transactionId': transactionId,
              'status': 'queued',
              'message': 'Saved locally, will sync when possible (backend error)',
            };
          }
        } on TimeoutException {
          // Timeout: queue for retry
          await _queueForSync(transactionId, moduleId, timestamp, cachedTransaction);

          return {
            'success': true,
            'transactionId': transactionId,
            'status': 'queued',
            'message': 'Saved locally, will sync when possible (timeout)',
          };
        } catch (e) {
          // Network error: queue for retry
          print('[OfflineBridgeExtension] Backend submission failed: $e');

          await _queueForSync(transactionId, moduleId, timestamp, cachedTransaction);

          return {
            'success': true,
            'transactionId': transactionId,
            'status': 'queued',
            'message': 'Saved locally, will sync when online',
          };
        }
      } else {
        // Offline: queue for sync
        print('[OfflineBridgeExtension] Offline: queueing for sync');

        await _queueForSync(transactionId, moduleId, timestamp, cachedTransaction);

        return {
          'success': true,
          'transactionId': transactionId,
          'status': 'queued',
          'message': 'Saved locally, will sync when online',
        };
      }
    } catch (e) {
      print('[OfflineBridgeExtension] Error submitting transaction: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Queue transaction for sync
  Future<void> _queueForSync(
    String transactionId,
    String moduleId,
    int timestamp,
    CachedTransaction cachedTx,
  ) async {
    final payload = json.encode(cachedTx.toJson());

    final offlineTransaction = OfflineTransaction(
      transactionId: transactionId,
      moduleId: moduleId,
      timestamp: timestamp,
      payload: payload,
      syncStatus: SyncStatus.pending,
      retryCount: 0,
    );

    await _queue.enqueue(offlineTransaction);

    print('[OfflineBridgeExtension] Transaction queued for sync: $transactionId');
  }

  /// Submit offline transaction from React module (DEPRECATED - use submitTransaction instead)
  /// Called when user submits transaction form
  /// Params: { moduleId, transactionType, payload }
  /// Returns: { success: bool, transactionId: string, error?: string }
  @Deprecated('Use submitTransaction instead for offline-first behavior')
  Future<Map<String, dynamic>> submitOfflineTransaction(Map<String, dynamic> args) async {
    try {
      // Extract and validate parameters
      final moduleId = args['moduleId'] as String?;
      final transactionType = args['transactionType'] as String?;
      final payloadString = args['payload'] as String?;

      if (moduleId == null || moduleId.isEmpty) {
        return {
          'success': false,
          'error': 'moduleId is required',
        };
      }

      if (transactionType == null || transactionType.isEmpty) {
        return {
          'success': false,
          'error': 'transactionType is required',
        };
      }

      if (payloadString == null || payloadString.isEmpty) {
        return {
          'success': false,
          'error': 'payload is required',
        };
      }

      // Validate payload size (< 1MB per Phase 3 constraint)
      final payloadBytes = utf8.encode(payloadString);
      if (payloadBytes.length > 1024 * 1024) {
        return {
          'success': false,
          'error': 'Transaction payload exceeds 1MB limit',
        };
      }

      // Generate transaction ID (UUID v4)
      final transactionId = _uuid.v4();

      // Create OfflineTransaction
      final transaction = OfflineTransaction(
        transactionId: transactionId,
        moduleId: moduleId,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        payload: payloadString,
        syncStatus: SyncStatus.pending,
        retryCount: 0,
      );

      print('[OfflineBridgeExtension] Submitting transaction: $transactionId for module: $moduleId');

      // Enqueue to OfflineTransactionQueue
      await _queue.enqueue(transaction);

      print('[OfflineBridgeExtension] Transaction queued successfully: $transactionId');

      // Simulate 2-second sync delay for demo visibility (as per validated.md)
      // This makes the sync progress visible during demos
      Future.delayed(const Duration(seconds: 2), () async {
        try {
          print('[OfflineBridgeExtension] Starting mock sync for transaction: $transactionId');
          await _mockSync(transactionId);
        } catch (e) {
          print('[OfflineBridgeExtension] Mock sync failed: $e');
        }
      });

      return {
        'success': true,
        'transactionId': transactionId,
        'message': 'Transaction queued successfully - will sync when online',
      };
    } catch (e) {
      print('[OfflineBridgeExtension] Error submitting transaction: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Mock sync function - simulates backend sync with 2-second delay
  /// This is for POC demo visibility only (per validated.md decision)
  Future<void> _mockSync(String transactionId) async {
    try {
      // Check if online before attempting sync
      final isOnline = await _networkMonitor.isOnline();
      if (!isOnline) {
        print('[OfflineBridgeExtension] Skipping mock sync - network offline');
        return;
      }

      print('[OfflineBridgeExtension] Mock sync in progress for: $transactionId');

      // Wait 2 seconds to simulate network delay (makes sync visible in demo)
      await Future.delayed(const Duration(seconds: 2));

      // Mark as synced (successful)
      await _queue.markSynced(transactionId);

      print('[OfflineBridgeExtension] Mock sync completed for: $transactionId');

      // In a real implementation, this would:
      // 1. Send payload to backend API
      // 2. Handle response/errors
      // 3. Update retry count on failure
      // 4. Trigger SyncManager for batch processing
    } catch (e) {
      print('[OfflineBridgeExtension] Mock sync error: $e');

      // Mark as failed on error (includes retry count logic)
      try {
        await _queue.markFailed(transactionId, e.toString());
      } catch (updateError) {
        print('[OfflineBridgeExtension] Failed to update sync status: $updateError');
      }
    }
  }
}
