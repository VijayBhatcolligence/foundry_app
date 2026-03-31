// Phase 2: Action Queue Database
// Purpose: SQLite database as source of truth for all user-generated actions
// This replaces the existing offline_transaction_queue with a generic action queue

import 'dart:async';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// Status of an action in the queue
enum ActionStatus {
  pending,  // Action waiting to be synced
  syncing,  // Action currently being synced
  synced,   // Action successfully synced to backend
  error     // Action failed validation or max retries reached
}

/// Represents a single action in the queue
class QueuedAction {
  final String id;
  final String moduleId;
  final String actionType;
  final String payload;
  ActionStatus status;
  int retryCount;
  String? errorMessage;
  final int createdAt;
  int updatedAt;

  QueuedAction({
    required this.id,
    required this.moduleId,
    required this.actionType,
    required this.payload,
    this.status = ActionStatus.pending,
    this.retryCount = 0,
    this.errorMessage,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Convert to database map
  Map<String, dynamic> toDbMap() {
    return {
      'id': id,
      'module_id': moduleId,
      'action_type': actionType,
      'payload': payload,
      'status': status.name,  // Store as string for readability
      'retry_count': retryCount,
      'error_message': errorMessage,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  /// Create from database map
  factory QueuedAction.fromDbMap(Map<String, dynamic> map) {
    return QueuedAction(
      id: map['id'] as String,
      moduleId: map['module_id'] as String,
      actionType: map['action_type'] as String,
      payload: map['payload'] as String,
      status: ActionStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => ActionStatus.pending,
      ),
      retryCount: map['retry_count'] as int,
      errorMessage: map['error_message'] as String?,
      createdAt: map['created_at'] as int,
      updatedAt: map['updated_at'] as int,
    );
  }

  /// Create a copy with updated fields
  QueuedAction copyWith({
    ActionStatus? status,
    int? retryCount,
    String? errorMessage,
    int? updatedAt,
  }) {
    return QueuedAction(
      id: id,
      moduleId: moduleId,
      actionType: actionType,
      payload: payload,
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
      errorMessage: errorMessage ?? this.errorMessage,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'QueuedAction(id: $id, moduleId: $moduleId, type: $actionType, status: ${status.name}, retries: $retryCount)';
  }
}

/// SQLite database for action queue (source of truth)
class ActionQueueDB {
  static final ActionQueueDB _instance = ActionQueueDB._internal();
  factory ActionQueueDB() => _instance;
  ActionQueueDB._internal();

  Database? _database;
  bool _isInitialized = false;

  static const String _dbName = 'action_queue.db';
  static const int _dbVersion = 1;
  static const String _tableName = 'action_queue';

  /// Returns true if database is initialized
  bool get isInitialized => _isInitialized;

  /// Initialize the database
  ///
  /// Creates the action_queue table with indexes
  /// Safe to call multiple times (idempotent)
  Future<void> initialize() async {
    if (_isInitialized && _database != null) {
      print('[ActionQueueDB] Already initialized');
      return;
    }

    try {
      print('[ActionQueueDB] ========================================');
      print('[ActionQueueDB] Initializing action queue database...');

      // Get database path
      final appDir = await getApplicationDocumentsDirectory();
      final dbPath = path.join(appDir.path, _dbName);

      print('[ActionQueueDB] Database path: $dbPath');

      // Open database
      _database = await openDatabase(
        dbPath,
        version: _dbVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );

      _isInitialized = true;

      print('[ActionQueueDB] ✅ Database initialized successfully');
      print('[ActionQueueDB] 📊 Version: $_dbVersion');
      print('[ActionQueueDB] 🗄️  Table: $_tableName');
      print('[ActionQueueDB] ========================================');

      // Log current statistics
      await _logStatistics();
    } catch (e) {
      print('[ActionQueueDB] ❌ Failed to initialize database: $e');
      rethrow;
    }
  }

  /// Create database schema
  Future<void> _onCreate(Database db, int version) async {
    print('[ActionQueueDB] Creating database schema...');

    // Create action_queue table
    await db.execute('''
      CREATE TABLE $_tableName (
        id TEXT PRIMARY KEY,
        module_id TEXT NOT NULL,
        action_type TEXT NOT NULL,
        payload TEXT NOT NULL,
        status TEXT DEFAULT 'pending',
        retry_count INTEGER DEFAULT 0,
        error_message TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    print('[ActionQueueDB] ✅ Table created: $_tableName');

    // Create indexes for performance
    await db.execute('''
      CREATE INDEX idx_module_status
      ON $_tableName(module_id, status)
    ''');

    await db.execute('''
      CREATE INDEX idx_status
      ON $_tableName(status)
    ''');

    await db.execute('''
      CREATE INDEX idx_created_at
      ON $_tableName(created_at DESC)
    ''');

    print('[ActionQueueDB] ✅ Indexes created (module_status, status, created_at)');
  }

  /// Upgrade database schema
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    print('[ActionQueueDB] Upgrading database from v$oldVersion to v$newVersion');

    // Add migration logic here when schema changes in future versions
    // For now, no migrations needed
  }

  /// Save a new action to the queue
  ///
  /// Returns the action ID on success
  /// Throws exception on error
  Future<String> saveAction(Map<String, dynamic> actionData) async {
    _ensureInitialized();

    try {
      final now = DateTime.now().millisecondsSinceEpoch;

      // Validate required fields
      if (!actionData.containsKey('id') || actionData['id'] == null) {
        throw ArgumentError('Action must have an id field');
      }
      if (!actionData.containsKey('module_id') || actionData['module_id'] == null) {
        throw ArgumentError('Action must have a module_id field');
      }
      if (!actionData.containsKey('action_type') || actionData['action_type'] == null) {
        throw ArgumentError('Action must have an action_type field');
      }
      if (!actionData.containsKey('payload') || actionData['payload'] == null) {
        throw ArgumentError('Action must have a payload field');
      }

      // Ensure payload is a string (JSON)
      String payloadStr;
      if (actionData['payload'] is String) {
        payloadStr = actionData['payload'];
      } else {
        payloadStr = jsonEncode(actionData['payload']);
      }

      // Create action map for database
      final dbMap = {
        'id': actionData['id'],
        'module_id': actionData['module_id'],
        'action_type': actionData['action_type'],
        'payload': payloadStr,
        'status': actionData['status'] ?? 'pending',
        'retry_count': actionData['retry_count'] ?? 0,
        'error_message': actionData['error_message'],
        'created_at': actionData['created_at'] ?? now,
        'updated_at': now,
      };

      await _database!.insert(
        _tableName,
        dbMap,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      print('[ActionQueueDB] ✅ Action saved: ${dbMap['id']} (${dbMap['module_id']}/${dbMap['action_type']})');

      return dbMap['id'] as String;
    } catch (e) {
      print('[ActionQueueDB] ❌ Error saving action: $e');
      rethrow;
    }
  }

  /// Get actions filtered by module ID and status
  ///
  /// Returns list of actions matching the criteria
  Future<List<Map<String, dynamic>>> getActions(
    String moduleId,
    String status,
  ) async {
    _ensureInitialized();

    try {
      final results = await _database!.query(
        _tableName,
        where: 'module_id = ? AND status = ?',
        whereArgs: [moduleId, status],
        orderBy: 'created_at ASC',
      );

      print('[ActionQueueDB] 📊 Found ${results.length} actions (module: $moduleId, status: $status)');

      return results;
    } catch (e) {
      print('[ActionQueueDB] ❌ Error getting actions: $e');
      rethrow;
    }
  }

  /// Get all actions for a module (all statuses)
  Future<List<Map<String, dynamic>>> getAllActionsForModule(String moduleId) async {
    _ensureInitialized();

    try {
      final results = await _database!.query(
        _tableName,
        where: 'module_id = ?',
        whereArgs: [moduleId],
        orderBy: 'created_at DESC',
      );

      print('[ActionQueueDB] 📊 Found ${results.length} total actions for module: $moduleId');

      return results;
    } catch (e) {
      print('[ActionQueueDB] ❌ Error getting all actions: $e');
      rethrow;
    }
  }

  /// Get pending count for a module
  Future<int> getPendingCount(String moduleId) async {
    _ensureInitialized();

    try {
      final result = await _database!.rawQuery(
        'SELECT COUNT(*) as count FROM $_tableName WHERE module_id = ? AND status = ?',
        [moduleId, 'pending'],
      );

      final count = Sqflite.firstIntValue(result) ?? 0;

      print('[ActionQueueDB] 📊 Pending count for $moduleId: $count');

      return count;
    } catch (e) {
      print('[ActionQueueDB] ❌ Error getting pending count: $e');
      rethrow;
    }
  }

  /// Update action status
  ///
  /// Returns true if update was successful
  Future<bool> updateActionStatus(
    String id,
    String status, [
    String? errorMessage,
  ]) async {
    _ensureInitialized();

    try {
      final now = DateTime.now().millisecondsSinceEpoch;

      final updates = {
        'status': status,
        'updated_at': now,
      };

      if (errorMessage != null) {
        updates['error_message'] = errorMessage;
      }

      final count = await _database!.update(
        _tableName,
        updates,
        where: 'id = ?',
        whereArgs: [id],
      );

      final success = count > 0;

      if (success) {
        print('[ActionQueueDB] ✅ Action $id updated to status: $status');
      } else {
        print('[ActionQueueDB] ⚠️  Action $id not found for update');
      }

      return success;
    } catch (e) {
      print('[ActionQueueDB] ❌ Error updating action status: $e');
      rethrow;
    }
  }

  /// Increment retry count for an action
  Future<bool> incrementRetryCount(String id) async {
    _ensureInitialized();

    try {
      final now = DateTime.now().millisecondsSinceEpoch;

      final count = await _database!.rawUpdate(
        'UPDATE $_tableName SET retry_count = retry_count + 1, updated_at = ? WHERE id = ?',
        [now, id],
      );

      final success = count > 0;

      if (success) {
        print('[ActionQueueDB] ✅ Incremented retry count for action: $id');
      } else {
        print('[ActionQueueDB] ⚠️  Action $id not found for retry increment');
      }

      return success;
    } catch (e) {
      print('[ActionQueueDB] ❌ Error incrementing retry count: $e');
      rethrow;
    }
  }

  /// Delete an action
  ///
  /// Returns true if deletion was successful
  Future<bool> deleteAction(String id) async {
    _ensureInitialized();

    try {
      final count = await _database!.delete(
        _tableName,
        where: 'id = ?',
        whereArgs: [id],
      );

      final success = count > 0;

      if (success) {
        print('[ActionQueueDB] ✅ Action deleted: $id');
      } else {
        print('[ActionQueueDB] ⚠️  Action $id not found for deletion');
      }

      return success;
    } catch (e) {
      print('[ActionQueueDB] ❌ Error deleting action: $e');
      rethrow;
    }
  }

  /// Delete all synced actions older than specified days
  ///
  /// Used for cleanup to prevent database bloat
  Future<int> deleteSyncedOlderThan(int days) async {
    _ensureInitialized();

    try {
      final cutoffTimestamp = DateTime.now()
          .subtract(Duration(days: days))
          .millisecondsSinceEpoch;

      final count = await _database!.delete(
        _tableName,
        where: 'status = ? AND created_at < ?',
        whereArgs: ['synced', cutoffTimestamp],
      );

      print('[ActionQueueDB] 🧹 Cleaned up $count synced actions older than $days days');

      return count;
    } catch (e) {
      print('[ActionQueueDB] ❌ Error cleaning up old actions: $e');
      rethrow;
    }
  }

  /// Get statistics about the action queue
  Future<Map<String, int>> getStatistics([String? moduleId]) async {
    _ensureInitialized();

    try {
      final whereClause = moduleId != null ? 'WHERE module_id = ?' : '';
      final whereArgs = moduleId != null ? [moduleId] : [];

      final result = await _database!.rawQuery('''
        SELECT
          status,
          COUNT(*) as count
        FROM $_tableName
        $whereClause
        GROUP BY status
      ''', whereArgs);

      final stats = <String, int>{
        'pending': 0,
        'syncing': 0,
        'synced': 0,
        'error': 0,
        'total': 0,
      };

      for (final row in result) {
        final status = row['status'] as String;
        final count = row['count'] as int;
        stats[status] = count;
        stats['total'] = stats['total']! + count;
      }

      return stats;
    } catch (e) {
      print('[ActionQueueDB] ❌ Error getting statistics: $e');
      rethrow;
    }
  }

  /// Log current statistics to console
  Future<void> _logStatistics() async {
    try {
      final stats = await getStatistics();

      print('[ActionQueueDB] 📊 Current Statistics:');
      print('[ActionQueueDB]   Total: ${stats['total']}');
      print('[ActionQueueDB]   Pending: ${stats['pending']}');
      print('[ActionQueueDB]   Syncing: ${stats['syncing']}');
      print('[ActionQueueDB]   Synced: ${stats['synced']}');
      print('[ActionQueueDB]   Error: ${stats['error']}');
    } catch (e) {
      print('[ActionQueueDB] ⚠️  Could not log statistics: $e');
    }
  }

  /// Close the database
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
      _isInitialized = false;
      print('[ActionQueueDB] Database closed');
    }
  }

  /// Ensure database is initialized before operations
  void _ensureInitialized() {
    if (!_isInitialized || _database == null) {
      throw StateError('ActionQueueDB not initialized. Call initialize() first.');
    }
  }

  /// Get raw database instance (for advanced queries)
  Database? get database => _database;
}
