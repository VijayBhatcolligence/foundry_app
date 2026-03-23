// D5.2: Fallback Manager Service
// Purpose: Track module load failures and automatic rollback to last-known-good

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'module_cache.dart';

class FallbackManager {
  static final FallbackManager instance = FallbackManager._internal();
  factory FallbackManager() => instance;
  FallbackManager._internal();

  Database? _database;

  // Failure thresholds
  static const int _failureThreshold = 3; // Triggers automatic rollback
  static const int _blockThreshold = 5; // Triggers permanent block

  // Record module load failure
  Future<void> recordLoadFailure({
    required String moduleId,
    required String version,
    required String error,
  }) async {
    try {
      final db = await _getDatabase();

      // Get current failure count
      final existing = await db.query(
        'module_failures',
        where: 'module_id = ? AND version = ?',
        whereArgs: [moduleId, version],
      );

      final currentCount = existing.isNotEmpty
          ? (existing.first['failure_count'] as int)
          : 0;

      await db.insert(
        'module_failures',
        {
          'module_id': moduleId,
          'version': version,
          'failure_count': currentCount + 1,
          'last_failure_at': DateTime.now().millisecondsSinceEpoch,
          'error_message': error,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      print('Error recording module failure: $e');
    }
  }

  // Get last-known-good version for module, returns null if no known-good version
  Future<String?> getLastKnownGoodVersion(String moduleId) async {
    try {
      final db = await _getDatabase();

      final results = await db.query(
        'last_known_good',
        where: 'module_id = ?',
        whereArgs: [moduleId],
      );

      if (results.isEmpty) return null;

      return results.first['version'] as String;
    } catch (e) {
      print('Error getting last-known-good version: $e');
      return null;
    }
  }

  // Mark version as last-known-good after successful load
  Future<void> markAsLastKnownGood({
    required String moduleId,
    required String version,
  }) async {
    try {
      final db = await _getDatabase();

      await db.insert(
        'last_known_good',
        {
          'module_id': moduleId,
          'version': version,
          'marked_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      throw StateError('Failed to mark last-known-good: $e');
    }
  }

  // Attempt automatic rollback, returns version rolled back to
  Future<FallbackResult> attemptFallback(String moduleId) async {
    try {
      // Get last-known-good version
      final lastGood = await getLastKnownGoodVersion(moduleId);

      if (lastGood == null) {
        return FallbackResult(
          success: false,
          error: 'No known-good version available',
          userNotificationRequired: true,
        );
      }

      // Check if last-known-good is in cache
      final cachedVersions = await ModuleCache.instance.listCachedVersions(moduleId);

      if (!cachedVersions.contains(lastGood)) {
        return FallbackResult(
          success: false,
          error: 'Fallback version not in cache',
          userNotificationRequired: true,
        );
      }

      // Check if last-known-good version has also failed
      final failureCount = await getFailureCount(moduleId, lastGood);
      if (failureCount >= _failureThreshold) {
        // Try next older cached version
        final olderVersions = cachedVersions.where((v) => v != lastGood).toList();

        if (olderVersions.isEmpty) {
          return FallbackResult(
            success: false,
            error: 'No working version available',
            userNotificationRequired: true,
          );
        }

        // Return first older version (assumes sorted)
        return FallbackResult(
          success: true,
          fallbackVersion: olderVersions.first,
          userNotificationRequired: true,
        );
      }

      return FallbackResult(
        success: true,
        fallbackVersion: lastGood,
        userNotificationRequired: false,
      );
    } catch (e) {
      return FallbackResult(
        success: false,
        error: e.toString(),
        userNotificationRequired: true,
      );
    }
  }

  // Get failure count for specific version
  Future<int> getFailureCount(String moduleId, String version) async {
    try {
      final db = await _getDatabase();

      final results = await db.query(
        'module_failures',
        columns: ['failure_count'],
        where: 'module_id = ? AND version = ?',
        whereArgs: [moduleId, version],
      );

      if (results.isEmpty) return 0;

      return results.first['failure_count'] as int;
    } catch (e) {
      print('Error getting failure count: $e');
      return 0;
    }
  }

  // Reset failure tracking for module (e.g., after successful load)
  Future<void> resetFailures(String moduleId) async {
    try {
      final db = await _getDatabase();

      await db.delete(
        'module_failures',
        where: 'module_id = ?',
        whereArgs: [moduleId],
      );
    } catch (e) {
      print('Error resetting failures: $e');
    }
  }

  // Check if module should be blocked from loading due to repeated failures
  Future<bool> isBlocked(String moduleId, String version) async {
    final failureCount = await getFailureCount(moduleId, version);
    return failureCount >= _blockThreshold;
  }

  // Private helper: Get database instance
  Future<Database> _getDatabase() async {
    if (_database != null) return _database!;

    final appDir = await getApplicationSupportDirectory();
    final dbPath = path.join(appDir.path, 'fallback_manager.db');

    _database = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE module_failures (
            module_id TEXT NOT NULL,
            version TEXT NOT NULL,
            failure_count INTEGER NOT NULL,
            last_failure_at INTEGER NOT NULL,
            error_message TEXT,
            PRIMARY KEY (module_id, version)
          )
        ''');

        await db.execute('''
          CREATE TABLE last_known_good (
            module_id TEXT PRIMARY KEY,
            version TEXT NOT NULL,
            marked_at INTEGER NOT NULL
          )
        ''');
      },
    );

    return _database!;
  }
}

class FallbackResult {
  final bool success;
  final String? fallbackVersion;
  final String? error;
  final bool userNotificationRequired;

  FallbackResult({
    required this.success,
    this.fallbackVersion,
    this.error,
    required this.userNotificationRequired,
  });
}
