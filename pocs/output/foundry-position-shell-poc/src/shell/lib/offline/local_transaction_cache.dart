// Phase 3: Local Transaction Cache Service
// Purpose: Manages local SQLite cache for read operations (offline-first)

import 'dart:async';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import '../database/offline_schema.dart';

/// Represents a cached transaction for read operations
class CachedTransaction {
  final int? id;
  final String transactionId;
  final String poNumber;
  final String vendor;
  final List<LineItem> lineItems;
  final int createdAt;
  final int? receivedAt;
  final String status; // 'local', 'synced', 'conflict'
  final int cachedAt;
  final bool isDirty;

  CachedTransaction({
    this.id,
    required this.transactionId,
    required this.poNumber,
    required this.vendor,
    required this.lineItems,
    required this.createdAt,
    this.receivedAt,
    this.status = 'local',
    required this.cachedAt,
    this.isDirty = false,
  });

  Map<String, dynamic> toDbMap() {
    return {
      if (id != null) 'id': id,
      'transaction_id': transactionId,
      'po_number': poNumber,
      'vendor': vendor,
      'line_items': json.encode(lineItems.map((item) => item.toJson()).toList()),
      'created_at': createdAt,
      'received_at': receivedAt,
      'status': status,
      'cached_at': cachedAt,
      'is_dirty': isDirty ? 1 : 0,
    };
  }

  factory CachedTransaction.fromDbMap(Map<String, dynamic> map) {
    final lineItemsJson = json.decode(map['line_items'] as String) as List<dynamic>;
    final lineItems = lineItemsJson
        .map((item) => LineItem.fromJson(item as Map<String, dynamic>))
        .toList();

    return CachedTransaction(
      id: map['id'] as int?,
      transactionId: map['transaction_id'] as String,
      poNumber: map['po_number'] as String,
      vendor: map['vendor'] as String,
      lineItems: lineItems,
      createdAt: map['created_at'] as int,
      receivedAt: map['received_at'] as int?,
      status: map['status'] as String,
      cachedAt: map['cached_at'] as int,
      isDirty: (map['is_dirty'] as int) == 1,
    );
  }

  /// Convert from backend API format
  /// Backend uses snake_case (transaction_id, po_number, line_items, created_at, received_at)
  /// Or camelCase (transactionId, poNumber, lineItems, createdAt, receivedAt)
  /// This factory supports both formats for compatibility
  factory CachedTransaction.fromApiJson(Map<String, dynamic> json) {
    // Support both snake_case (from backend DB) and camelCase (from API)
    final lineItemsJson = (json['lineItems'] ?? json['line_items']) as List<dynamic>;
    final lineItems = lineItemsJson
        .map((item) => LineItem.fromJson(item as Map<String, dynamic>))
        .toList();

    return CachedTransaction(
      transactionId: (json['transactionId'] ?? json['transaction_id']) as String,
      poNumber: (json['poNumber'] ?? json['po_number']) as String,
      vendor: json['vendor'] as String,
      lineItems: lineItems,
      createdAt: (json['createdAt'] ?? json['created_at']) as int,
      receivedAt: (json['receivedAt'] ?? json['received_at']) as int?,
      status: 'synced',
      cachedAt: DateTime.now().millisecondsSinceEpoch,
      isDirty: false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'transactionId': transactionId,
      'poNumber': poNumber,
      'vendor': vendor,
      'lineItems': lineItems.map((item) => item.toJson()).toList(),
      'createdAt': createdAt,
      'receivedAt': receivedAt,
      'status': status,
      'cachedAt': cachedAt,
      'isDirty': isDirty,
    };
  }
}

class LineItem {
  final String sku;
  final String description;
  final int quantity;
  final String location;

  LineItem({
    required this.sku,
    required this.description,
    required this.quantity,
    required this.location,
  });

  Map<String, dynamic> toJson() {
    return {
      'sku': sku,
      'description': description,
      'quantity': quantity,
      'location': location,
    };
  }

  factory LineItem.fromJson(Map<String, dynamic> json) {
    // Handle quantity as either int or string (backend may store as string)
    final quantityValue = json['quantity'];
    final quantity = quantityValue is int
        ? quantityValue
        : int.parse(quantityValue.toString());

    return LineItem(
      sku: json['sku'] as String,
      description: json['description'] as String? ?? '',
      quantity: quantity,
      location: json['location'] as String,
    );
  }
}

class CacheStats {
  final int totalCount;
  final int localCount;
  final int syncedCount;
  final int dirtyCount;
  final int oldestTimestamp;
  final int newestTimestamp;
  final int cacheSizeBytes;

  CacheStats({
    required this.totalCount,
    required this.localCount,
    required this.syncedCount,
    required this.dirtyCount,
    required this.oldestTimestamp,
    required this.newestTimestamp,
    required this.cacheSizeBytes,
  });
}

class LocalTransactionCache {
  static final LocalTransactionCache instance = LocalTransactionCache._internal();
  factory LocalTransactionCache() => instance;
  LocalTransactionCache._internal();

  Database? _database;

  // Cache configuration (stored in sync_metadata)
  static const int defaultMaxCacheSize = 500;
  static const int defaultMaxCacheDays = 7;

  /// Get database instance
  Future<Database> _getDatabase() async {
    if (_database != null) return _database!;

    final appDir = await getApplicationSupportDirectory();
    final dbPath = path.join(appDir.path, 'offline_transactions.db');

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
  }

  /// Insert or update a transaction in cache
  Future<void> upsert(CachedTransaction transaction) async {
    final db = await _getDatabase();

    await db.insert(
      'local_transactions',
      transaction.toDbMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    print('[LocalTransactionCache] Transaction upserted: ${transaction.transactionId}');

    // Cleanup old cache if needed
    await _cleanupOldCache();
  }

  /// Bulk insert/update transactions (for sync download)
  Future<void> upsertBatch(List<CachedTransaction> transactions) async {
    if (transactions.isEmpty) return;

    final db = await _getDatabase();

    await db.transaction((txn) async {
      for (final transaction in transactions) {
        await txn.insert(
          'local_transactions',
          transaction.toDbMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });

    print('[LocalTransactionCache] Batch upserted: ${transactions.length} transactions');

    // Cleanup old cache
    await _cleanupOldCache();
  }

  /// Get all cached transactions (most recent first)
  Future<List<CachedTransaction>> getAll({int? limit}) async {
    final db = await _getDatabase();

    final results = await db.query(
      'local_transactions',
      orderBy: 'created_at DESC',
      limit: limit,
    );

    return results.map((map) => CachedTransaction.fromDbMap(map)).toList();
  }

  /// Get recent transactions (last N days)
  Future<List<CachedTransaction>> getRecent({int days = 7}) async {
    final db = await _getDatabase();

    final cutoffTimestamp = DateTime.now()
        .subtract(Duration(days: days))
        .millisecondsSinceEpoch;

    final results = await db.query(
      'local_transactions',
      where: 'created_at >= ?',
      whereArgs: [cutoffTimestamp],
      orderBy: 'created_at DESC',
    );

    return results.map((map) => CachedTransaction.fromDbMap(map)).toList();
  }

  /// Get transaction by ID
  Future<CachedTransaction?> getById(String transactionId) async {
    final db = await _getDatabase();

    final results = await db.query(
      'local_transactions',
      where: 'transaction_id = ?',
      whereArgs: [transactionId],
      limit: 1,
    );

    if (results.isEmpty) return null;

    return CachedTransaction.fromDbMap(results.first);
  }

  /// Check if transaction exists in cache
  Future<bool> exists(String transactionId) async {
    final db = await _getDatabase();

    final result = await db.rawQuery('''
      SELECT COUNT(*) as count
      FROM local_transactions
      WHERE transaction_id = ?
    ''', [transactionId]);

    return (Sqflite.firstIntValue(result) ?? 0) > 0;
  }

  /// Get cache statistics
  Future<CacheStats> getStats() async {
    final db = await _getDatabase();

    // Total count
    final countResult = await db.rawQuery('''
      SELECT COUNT(*) as count FROM local_transactions
    ''');
    final totalCount = Sqflite.firstIntValue(countResult) ?? 0;

    // Status counts
    final statusCounts = await db.rawQuery('''
      SELECT status, COUNT(*) as count
      FROM local_transactions
      GROUP BY status
    ''');

    int localCount = 0;
    int syncedCount = 0;
    for (final row in statusCounts) {
      final status = row['status'] as String;
      final count = row['count'] as int;
      if (status == 'local') localCount = count;
      if (status == 'synced') syncedCount = count;
    }

    // Dirty count
    final dirtyResult = await db.rawQuery('''
      SELECT COUNT(*) as count
      FROM local_transactions
      WHERE is_dirty = 1
    ''');
    final dirtyCount = Sqflite.firstIntValue(dirtyResult) ?? 0;

    // Timestamp range
    final timestampResult = await db.rawQuery('''
      SELECT MIN(created_at) as oldest, MAX(created_at) as newest
      FROM local_transactions
    ''');

    final oldest = timestampResult.first['oldest'] as int? ?? 0;
    final newest = timestampResult.first['newest'] as int? ?? 0;

    // Approximate size (payload length sum)
    final sizeResult = await db.rawQuery('''
      SELECT SUM(LENGTH(line_items)) as total_size
      FROM local_transactions
    ''');

    final cacheSizeBytes = sizeResult.first['total_size'] as int? ?? 0;

    return CacheStats(
      totalCount: totalCount,
      localCount: localCount,
      syncedCount: syncedCount,
      dirtyCount: dirtyCount,
      oldestTimestamp: oldest,
      newestTimestamp: newest,
      cacheSizeBytes: cacheSizeBytes,
    );
  }

  /// Mark transaction as dirty (modified locally)
  Future<void> markDirty(String transactionId) async {
    final db = await _getDatabase();

    await db.update(
      'local_transactions',
      {'is_dirty': 1},
      where: 'transaction_id = ?',
      whereArgs: [transactionId],
    );

    print('[LocalTransactionCache] Transaction marked dirty: $transactionId');
  }

  /// Mark transaction as synced
  Future<void> markSynced(String transactionId) async {
    final db = await _getDatabase();

    await db.update(
      'local_transactions',
      {
        'status': 'synced',
        'is_dirty': 0,
      },
      where: 'transaction_id = ?',
      whereArgs: [transactionId],
    );

    print('[LocalTransactionCache] Transaction marked synced: $transactionId');
  }

  /// Delete transaction from cache
  Future<void> delete(String transactionId) async {
    final db = await _getDatabase();

    await db.delete(
      'local_transactions',
      where: 'transaction_id = ?',
      whereArgs: [transactionId],
    );

    print('[LocalTransactionCache] Transaction deleted: $transactionId');
  }

  /// Clear all cached transactions
  Future<void> clearAll() async {
    final db = await _getDatabase();

    await db.delete('local_transactions');

    print('[LocalTransactionCache] All cache cleared');
  }

  /// Cleanup old cache entries based on size and age limits
  Future<void> _cleanupOldCache() async {
    final db = await _getDatabase();

    // Get cache limits from metadata
    final maxSize = await _getMetadataInt('cache_size_limit', defaultMaxCacheSize);
    final maxDays = await _getMetadataInt('cache_days_limit', defaultMaxCacheDays);

    // Delete transactions older than max days
    final cutoffTimestamp = DateTime.now()
        .subtract(Duration(days: maxDays))
        .millisecondsSinceEpoch;

    final oldDeleted = await db.delete(
      'local_transactions',
      where: 'created_at < ? AND is_dirty = 0',
      whereArgs: [cutoffTimestamp],
    );

    if (oldDeleted > 0) {
      print('[LocalTransactionCache] Cleaned up $oldDeleted old transactions (> $maxDays days)');
    }

    // If still over size limit, delete oldest non-dirty transactions
    final countResult = await db.rawQuery('''
      SELECT COUNT(*) as count FROM local_transactions
    ''');
    final currentCount = Sqflite.firstIntValue(countResult) ?? 0;

    if (currentCount > maxSize) {
      final excessCount = currentCount - maxSize;

      // Get oldest non-dirty transaction IDs
      final oldestTransactions = await db.query(
        'local_transactions',
        columns: ['id'],
        where: 'is_dirty = 0',
        orderBy: 'created_at ASC',
        limit: excessCount,
      );

      final idsToDelete = oldestTransactions.map((row) => row['id'] as int).toList();

      if (idsToDelete.isNotEmpty) {
        await db.delete(
          'local_transactions',
          where: 'id IN (${idsToDelete.join(',')})',
        );

        print('[LocalTransactionCache] Cleaned up $excessCount transactions (over size limit)');
      }
    }
  }

  /// Get metadata value as int
  Future<int> _getMetadataInt(String key, int defaultValue) async {
    final db = await _getDatabase();

    final results = await db.query(
      'sync_metadata',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );

    if (results.isEmpty) return defaultValue;

    return int.tryParse(results.first['value'] as String) ?? defaultValue;
  }

  /// Dispose and close database
  Future<void> dispose() async {
    await _database?.close();
    _database = null;
  }
}
