// Phase 3: Database Schema for Offline Transactions
// Purpose: Define SQLite schema for offline transaction queue

import 'package:sqflite/sqflite.dart';

class OfflineSchema {
  static const int schemaVersion = 2;

  static Future<void> createSchema(Database db, int version) async {
    // Offline transactions table (write queue)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS offline_transactions (
        transaction_id TEXT PRIMARY KEY,
        module_id TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        payload TEXT NOT NULL,
        sync_status INTEGER NOT NULL DEFAULT 0,
        retry_count INTEGER NOT NULL DEFAULT 0,
        last_error TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // Indexes for performance
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_sync_status
      ON offline_transactions(sync_status)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_module_id
      ON offline_transactions(module_id)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_timestamp
      ON offline_transactions(timestamp)
    ''');

    // Local transaction cache table (read cache) - Phase 3 Full Offline
    await db.execute('''
      CREATE TABLE IF NOT EXISTS local_transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transaction_id TEXT UNIQUE NOT NULL,
        po_number TEXT NOT NULL,
        vendor TEXT NOT NULL,
        line_items TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        received_at INTEGER,
        status TEXT DEFAULT 'local',
        cached_at INTEGER NOT NULL,
        is_dirty INTEGER DEFAULT 0
      )
    ''');

    // Indexes for local_transactions
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_local_tx_id
      ON local_transactions(transaction_id)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_local_created_at
      ON local_transactions(created_at DESC)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_local_cached_at
      ON local_transactions(cached_at DESC)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_local_status
      ON local_transactions(status)
    ''');

    // Sync metadata table - Phase 3 Full Offline
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_metadata (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // Initialize default metadata
    await db.insert('sync_metadata', {
      'key': 'last_sync_timestamp',
      'value': '0',
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    await db.insert('sync_metadata', {
      'key': 'last_sync_status',
      'value': 'never',
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    await db.insert('sync_metadata', {
      'key': 'cache_size_limit',
      'value': '500',
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    await db.insert('sync_metadata', {
      'key': 'cache_days_limit',
      'value': '7',
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    // Conflict log table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS conflict_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transaction_id TEXT NOT NULL,
        local_timestamp INTEGER NOT NULL,
        remote_timestamp INTEGER NOT NULL,
        winner TEXT NOT NULL,
        reason TEXT NOT NULL,
        resolved_at INTEGER NOT NULL
      )
    ''');

    // Sync history table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        started_at INTEGER NOT NULL,
        completed_at INTEGER,
        total_transactions INTEGER NOT NULL,
        synced_count INTEGER NOT NULL,
        failed_count INTEGER NOT NULL,
        downloaded_count INTEGER DEFAULT 0,
        error TEXT
      )
    ''');

    // Set schema version
    await db.execute('PRAGMA user_version = $schemaVersion');
  }

  static Future<void> migrate(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < newVersion) {
      print('[OfflineSchema] Migrating from version $oldVersion to $newVersion');

      // Migration from version 1 to 2 (Phase 3 Full Offline)
      if (oldVersion == 1 && newVersion >= 2) {
        await _migrateV1toV2(db);
      }
    }
  }

  static Future<void> _migrateV1toV2(Database db) async {
    print('[OfflineSchema] Migrating v1 to v2: Adding local_transactions and sync_metadata tables');

    // Add local_transactions table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS local_transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transaction_id TEXT UNIQUE NOT NULL,
        po_number TEXT NOT NULL,
        vendor TEXT NOT NULL,
        line_items TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        received_at INTEGER,
        status TEXT DEFAULT 'local',
        cached_at INTEGER NOT NULL,
        is_dirty INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_local_tx_id
      ON local_transactions(transaction_id)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_local_created_at
      ON local_transactions(created_at DESC)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_local_cached_at
      ON local_transactions(cached_at DESC)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_local_status
      ON local_transactions(status)
    ''');

    // Add sync_metadata table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_metadata (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // Initialize metadata
    await db.insert('sync_metadata', {
      'key': 'last_sync_timestamp',
      'value': '0',
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    await db.insert('sync_metadata', {
      'key': 'last_sync_status',
      'value': 'never',
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    await db.insert('sync_metadata', {
      'key': 'cache_size_limit',
      'value': '500',
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    await db.insert('sync_metadata', {
      'key': 'cache_days_limit',
      'value': '7',
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    // Add downloaded_count column to sync_history
    try {
      await db.execute('''
        ALTER TABLE sync_history ADD COLUMN downloaded_count INTEGER DEFAULT 0
      ''');
    } catch (e) {
      // Column might already exist
      print('[OfflineSchema] Column downloaded_count already exists or migration failed: $e');
    }

    print('[OfflineSchema] Migration v1 to v2 completed successfully');
  }
}
