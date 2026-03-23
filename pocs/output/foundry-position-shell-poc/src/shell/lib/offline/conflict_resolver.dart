// Phase 3: Conflict Resolver Component
// Purpose: Resolves conflicts between offline and online data using last-write-wins strategy

import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'offline_transaction_queue.dart';
import 'local_transaction_cache.dart';

enum TransactionSource {
  local,
  remote
}

class ServerTransaction {
  final String transactionId;
  final int timestamp;
  final Map<String, dynamic> data;
  final int? deletedAt;

  ServerTransaction({
    required this.transactionId,
    required this.timestamp,
    required this.data,
    this.deletedAt,
  });
}

class ConflictResolution {
  final TransactionSource winner;
  final String reason;
  final Map<String, dynamic>? mergedData;

  ConflictResolution({
    required this.winner,
    required this.reason,
    this.mergedData,
  });
}

class ConflictResolver {
  static final ConflictResolver instance = ConflictResolver._internal();
  factory ConflictResolver() => instance;
  ConflictResolver._internal();

  Database? _database;
  final LocalTransactionCache _cache = LocalTransactionCache.instance;

  // Timestamp tolerance: 1000ms (1 second)
  static const int timestampToleranceMs = 1000;

  Future<ConflictResolution> resolve(
    OfflineTransaction local,
    ServerTransaction remote,
  ) async {
    // Compare timestamps
    final timeDiff = local.timestamp - remote.timestamp;
    final timeDiffAbs = timeDiff.abs();

    ConflictResolution resolution;

    // Check if remote transaction was deleted
    if (remote.deletedAt != null) {
      if (local.timestamp > remote.deletedAt!) {
        // Local transaction is newer than deletion, resurrect local
        resolution = ConflictResolution(
          winner: TransactionSource.local,
          reason: 'Local transaction newer than remote deletion',
          mergedData: null,
        );
      } else {
        // Keep deleted
        resolution = ConflictResolution(
          winner: TransactionSource.remote,
          reason: 'Remote deletion is authoritative',
          mergedData: null,
        );
      }
    } else if (timeDiffAbs > 365 * 24 * 60 * 60 * 1000) {
      // Timestamps differ by more than 1 year - possible clock sync issue
      print('[ConflictResolver] WARNING: Timestamps differ by > 1 year, possible clock sync issue');
      resolution = ConflictResolution(
        winner: TransactionSource.remote,
        reason: 'Server authoritative due to large timestamp difference (possible clock skew)',
        mergedData: null,
      );
    } else if (timeDiffAbs <= timestampToleranceMs) {
      // Timestamps within tolerance (1000ms), remote wins (server authoritative)
      resolution = ConflictResolution(
        winner: TransactionSource.remote,
        reason: 'Timestamps equal within tolerance, server authoritative',
        mergedData: null,
      );
    } else {
      // Clear winner based on timestamp
      if (local.timestamp > remote.timestamp) {
        resolution = ConflictResolution(
          winner: TransactionSource.local,
          reason: 'Local transaction has newer timestamp',
          mergedData: null,
        );
      } else {
        resolution = ConflictResolution(
          winner: TransactionSource.remote,
          reason: 'Remote transaction has newer timestamp',
          mergedData: null,
        );
      }
    }

    // Log conflict resolution
    await _logConflict(
      transactionId: local.transactionId,
      localTimestamp: local.timestamp,
      remoteTimestamp: remote.timestamp,
      winner: resolution.winner,
      reason: resolution.reason,
    );

    return resolution;
  }

  /// Resolve conflict between cached transaction and downloaded transaction (Phase 3 Full Offline)
  Future<ConflictResolution> resolveCacheConflict(
    CachedTransaction cachedTx,
    CachedTransaction downloadedTx,
  ) async {
    // Compare timestamps
    final timeDiff = cachedTx.createdAt - downloadedTx.createdAt;
    final timeDiffAbs = timeDiff.abs();

    ConflictResolution resolution;

    // Check if cached transaction is dirty (modified locally)
    if (cachedTx.isDirty) {
      // Dirty local transaction always wins (user has modified it)
      resolution = ConflictResolution(
        winner: TransactionSource.local,
        reason: 'Local transaction is dirty (modified locally), takes precedence',
        mergedData: null,
      );
    } else if (timeDiffAbs <= timestampToleranceMs) {
      // Timestamps within tolerance (1000ms), remote wins (server authoritative)
      resolution = ConflictResolution(
        winner: TransactionSource.remote,
        reason: 'Timestamps equal within tolerance, server authoritative',
        mergedData: null,
      );
    } else {
      // Clear winner based on timestamp (Last Write Wins)
      if (cachedTx.createdAt > downloadedTx.createdAt) {
        resolution = ConflictResolution(
          winner: TransactionSource.local,
          reason: 'Local cached transaction has newer timestamp',
          mergedData: null,
        );
      } else {
        resolution = ConflictResolution(
          winner: TransactionSource.remote,
          reason: 'Remote transaction has newer timestamp',
          mergedData: null,
        );
      }
    }

    // Log conflict resolution
    await _logConflict(
      transactionId: cachedTx.transactionId,
      localTimestamp: cachedTx.createdAt,
      remoteTimestamp: downloadedTx.createdAt,
      winner: resolution.winner,
      reason: resolution.reason,
    );

    // Apply resolution to cache
    if (resolution.winner == TransactionSource.remote) {
      // Remote wins, update cache with downloaded transaction
      await _cache.upsert(downloadedTx);
      print('[ConflictResolver] Cache updated with remote transaction: ${downloadedTx.transactionId}');
    } else {
      // Local wins, keep cached version
      print('[ConflictResolver] Keeping local cached transaction: ${cachedTx.transactionId}');
    }

    return resolution;
  }

  // Private: Log conflict to database
  Future<void> _logConflict({
    required String transactionId,
    required int localTimestamp,
    required int remoteTimestamp,
    required TransactionSource winner,
    required String reason,
  }) async {
    try {
      final db = await _getDatabase();

      await db.insert('conflict_log', {
        'transaction_id': transactionId,
        'local_timestamp': localTimestamp,
        'remote_timestamp': remoteTimestamp,
        'winner': winner.name,
        'reason': reason,
        'resolved_at': DateTime.now().millisecondsSinceEpoch,
      });

      print('[ConflictResolver] Conflict logged: $transactionId (winner: ${winner.name})');
    } catch (e) {
      print('[ConflictResolver] Failed to log conflict: $e');
    }
  }

  // Private: Get database instance (reuse offline transactions database)
  Future<Database> _getDatabase() async {
    if (_database != null) return _database!;

    final appDir = await getApplicationSupportDirectory();
    final dbPath = path.join(appDir.path, 'offline_transactions.db');

    _database = await openDatabase(dbPath);
    return _database!;
  }
}
