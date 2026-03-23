// D5.1: Module Cache Manager
// Purpose: Manage module cache directory, size limits, and garbage collection

import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'module_manifest.dart';

class ModuleCache {
  static final ModuleCache instance = ModuleCache._internal();
  factory ModuleCache() => instance;
  ModuleCache._internal();

  // Mutex for concurrent operations
  bool _operationInProgress = false;

  // Maximum cache size: 100 MB
  static const int _maxCacheSizeBytes = 104857600;
  static const int _autoGCTriggerBytes = 94371840; // 90 MB

  // Get path to cached module file, returns null if not cached
  Future<String?> getCachedModulePath(String moduleId, String version) async {
    final cacheDir = await getCacheDirectory();
    final modulePath = path.join(cacheDir, moduleId, version, 'module.js');

    final file = File(modulePath);
    if (await file.exists()) {
      // Update lastAccessedAt in metadata
      await _updateAccessTime(moduleId, version);
      return modulePath;
    }

    return null;
  }

  // Add module to cache from temporary file (atomic move operation)
  Future<CacheAddResult> addToCache({
    required String moduleId,
    required String version,
    required String tempFilePath,
    required ModuleManifest manifest,
  }) async {
    // Wait for any in-progress operations
    while (_operationInProgress) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    _operationInProgress = true;

    try {
      final cacheDir = await getCacheDirectory();
      final moduleDir = path.join(cacheDir, moduleId, version);

      // Ensure directory exists
      await Directory(moduleDir).create(recursive: true);

      // Check if auto-GC needed
      final currentSize = await getCacheSize();
      if (currentSize >= _autoGCTriggerBytes) {
        print('Cache size ($currentSize bytes) exceeds trigger, running garbage collection');
        await runGarbageCollection();
      }

      // Copy temp file to cache (atomic operation)
      final tempFile = File(tempFilePath);
      if (!await tempFile.exists()) {
        return CacheAddResult(
          success: false,
          error: 'Temporary file not found',
        );
      }

      final tempPath = path.join(moduleDir, 'module.js.tmp');
      final finalPath = path.join(moduleDir, 'module.js');

      // Copy to .tmp file first
      await tempFile.copy(tempPath);

      // Verify copy
      final tmpFile = File(tempPath);
      if (!await tmpFile.exists()) {
        return CacheAddResult(
          success: false,
          error: 'Failed to copy to cache',
        );
      }

      // Rename to final name (atomic on most filesystems)
      await tmpFile.rename(finalPath);

      // Save manifest
      final manifestPath = path.join(moduleDir, 'module.manifest.json');
      await File(manifestPath).writeAsString(json.encode(manifest.toJson()));

      // Save signature
      final signaturePath = path.join(moduleDir, 'module.signature');
      await File(signaturePath).writeAsString(manifest.signature);

      // Save cache metadata
      final metadata = {
        'moduleId': moduleId,
        'version': version,
        'cachedAt': DateTime.now().toIso8601String(),
        'lastAccessedAt': DateTime.now().toIso8601String(),
        'sizeBytes': await File(finalPath).length(),
      };
      final metadataPath = path.join(moduleDir, 'cache_metadata.json');
      await File(metadataPath).writeAsString(json.encode(metadata));

      return CacheAddResult(
        success: true,
        cachedFilePath: finalPath,
      );
    } on FileSystemException catch (e) {
      if (e.message.contains('No space')) {
        return CacheAddResult(
          success: false,
          error: 'Disk full',
        );
      }
      return CacheAddResult(
        success: false,
        error: 'File system error: $e',
      );
    } catch (e) {
      return CacheAddResult(
        success: false,
        error: e.toString(),
      );
    } finally {
      _operationInProgress = false;
    }
  }

  // Remove specific version from cache
  Future<void> removeFromCache(String moduleId, String version) async {
    try {
      final cacheDir = await getCacheDirectory();
      final moduleDir = path.join(cacheDir, moduleId, version);

      final dir = Directory(moduleDir);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (e) {
      print('Warning: Failed to remove module from cache: $e');
    }
  }

  // List all cached versions for module
  Future<List<String>> listCachedVersions(String moduleId) async {
    try {
      final cacheDir = await getCacheDirectory();
      final moduleDir = path.join(cacheDir, moduleId);

      final dir = Directory(moduleDir);
      if (!await dir.exists()) {
        return [];
      }

      final versions = <String>[];
      await for (final entity in dir.list()) {
        if (entity is Directory) {
          final version = path.basename(entity.path);
          final modulePath = path.join(entity.path, 'module.js');
          if (await File(modulePath).exists()) {
            versions.add(version);
          }
        }
      }

      return versions;
    } catch (e) {
      print('Warning: Failed to list cached versions: $e');
      return [];
    }
  }

  // Get total cache size in bytes
  Future<int> getCacheSize() async {
    try {
      final cacheDir = await getCacheDirectory();
      final dir = Directory(cacheDir);

      if (!await dir.exists()) {
        return 0;
      }

      int totalSize = 0;
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }

      return totalSize;
    } catch (e) {
      print('Warning: Failed to calculate cache size: $e');
      return 0;
    }
  }

  // Run garbage collection (remove old versions, enforce size limit)
  Future<GarbageCollectionResult> runGarbageCollection() async {
    final startTime = DateTime.now();
    int filesRemoved = 0;
    int bytesFreed = 0;
    final removedVersions = <String>[];

    try {
      final cacheDir = await getCacheDirectory();
      final dir = Directory(cacheDir);

      if (!await dir.exists()) {
        return GarbageCollectionResult(
          filesRemoved: 0,
          bytesFreed: 0,
          duration: DateTime.now().difference(startTime),
        );
      }

      // Get all cached modules with metadata
      final modules = await _getAllCachedModules();

      // Group by moduleId
      final moduleGroups = <String, List<Map<String, dynamic>>>{};
      for (final module in modules) {
        final moduleId = module['moduleId'] as String;
        moduleGroups.putIfAbsent(moduleId, () => []);
        moduleGroups[moduleId]!.add(module);
      }

      // Remove versions beyond 3-version limit per module
      for (final moduleId in moduleGroups.keys) {
        final versions = moduleGroups[moduleId]!;

        // Sort by cachedAt descending
        versions.sort((a, b) {
          final aTime = DateTime.parse(a['cachedAt'] as String);
          final bTime = DateTime.parse(b['cachedAt'] as String);
          return bTime.compareTo(aTime);
        });

        // Keep only 3 most recent (skip if marked as last-known-good)
        for (int i = 3; i < versions.length; i++) {
          final version = versions[i];

          // Check if last-known-good (don't remove)
          if (version['isLastKnownGood'] == true) {
            continue;
          }

          final versionStr = version['version'] as String;
          final size = version['sizeBytes'] as int;

          await removeFromCache(moduleId, versionStr);
          filesRemoved++;
          bytesFreed += size;
          removedVersions.add('$moduleId:$versionStr');
        }
      }

      // If still over limit, remove oldest accessed modules
      final currentSize = await getCacheSize();
      if (currentSize > _maxCacheSizeBytes) {
        // Sort all modules by lastAccessedAt
        modules.sort((a, b) {
          final aTime = DateTime.parse(a['lastAccessedAt'] as String);
          final bTime = DateTime.parse(b['lastAccessedAt'] as String);
          return aTime.compareTo(bTime);
        });

        for (final module in modules) {
          if (await getCacheSize() <= _maxCacheSizeBytes) break;

          // Skip last-known-good
          if (module['isLastKnownGood'] == true) continue;

          final moduleId = module['moduleId'] as String;
          final version = module['version'] as String;
          final size = module['sizeBytes'] as int;

          await removeFromCache(moduleId, version);
          filesRemoved++;
          bytesFreed += size;
          removedVersions.add('$moduleId:$version');
        }
      }

      // Clean up orphaned files
      await _cleanupOrphanedFiles();

      return GarbageCollectionResult(
        filesRemoved: filesRemoved,
        bytesFreed: bytesFreed,
        duration: DateTime.now().difference(startTime),
        removedVersions: removedVersions,
      );
    } catch (e) {
      print('Warning: Garbage collection encountered errors: $e');
      return GarbageCollectionResult(
        filesRemoved: filesRemoved,
        bytesFreed: bytesFreed,
        duration: DateTime.now().difference(startTime),
        removedVersions: removedVersions,
      );
    }
  }

  // Get cache directory path
  Future<String> getCacheDirectory() async {
    final appSupport = await getApplicationSupportDirectory();
    return path.join(appSupport.path, 'module_cache');
  }

  // Private helper: Update access time
  Future<void> _updateAccessTime(String moduleId, String version) async {
    try {
      final cacheDir = await getCacheDirectory();
      final metadataPath = path.join(cacheDir, moduleId, version, 'cache_metadata.json');

      final file = File(metadataPath);
      if (await file.exists()) {
        final metadata = json.decode(await file.readAsString()) as Map<String, dynamic>;
        metadata['lastAccessedAt'] = DateTime.now().toIso8601String();
        await file.writeAsString(json.encode(metadata));
      }
    } catch (e) {
      // Ignore errors updating access time
    }
  }

  // Private helper: Get all cached modules with metadata
  Future<List<Map<String, dynamic>>> _getAllCachedModules() async {
    final modules = <Map<String, dynamic>>[];

    try {
      final cacheDir = await getCacheDirectory();
      final dir = Directory(cacheDir);

      if (!await dir.exists()) {
        return modules;
      }

      await for (final moduleEntity in dir.list()) {
        if (moduleEntity is Directory) {
          final moduleId = path.basename(moduleEntity.path);

          await for (final versionEntity in moduleEntity.list()) {
            if (versionEntity is Directory) {
              final version = path.basename(versionEntity.path);
              final metadataPath = path.join(versionEntity.path, 'cache_metadata.json');

              if (await File(metadataPath).exists()) {
                try {
                  final metadata = json.decode(await File(metadataPath).readAsString()) as Map<String, dynamic>;
                  metadata['isLastKnownGood'] = false; // TODO: Check from fallback_manager
                  modules.add(metadata);
                } catch (e) {
                  print('Warning: Failed to parse metadata for $moduleId:$version');
                }
              }
            }
          }
        }
      }
    } catch (e) {
      print('Warning: Failed to get cached modules: $e');
    }

    return modules;
  }

  // Private helper: Clean up orphaned files
  Future<void> _cleanupOrphanedFiles() async {
    try {
      final cacheDir = await getCacheDirectory();
      final dir = Directory(cacheDir);

      if (!await dir.exists()) return;

      await for (final moduleEntity in dir.list()) {
        if (moduleEntity is Directory) {
          await for (final versionEntity in moduleEntity.list()) {
            if (versionEntity is Directory) {
              final modulePath = path.join(versionEntity.path, 'module.js');
              final metadataPath = path.join(versionEntity.path, 'cache_metadata.json');

              // If module.js missing but metadata exists, remove directory
              if (!await File(modulePath).exists() && await File(metadataPath).exists()) {
                await versionEntity.delete(recursive: true);
              }
            }
          }
        }
      }
    } catch (e) {
      print('Warning: Failed to cleanup orphaned files: $e');
    }
  }
}

class CacheAddResult {
  final bool success;
  final String? cachedFilePath;
  final String? error;

  CacheAddResult({
    required this.success,
    this.cachedFilePath,
    this.error,
  });
}

class GarbageCollectionResult {
  final int filesRemoved;
  final int bytesFreed;
  final Duration duration;
  final List<String> removedVersions;

  GarbageCollectionResult({
    required this.filesRemoved,
    required this.bytesFreed,
    required this.duration,
    this.removedVersions = const [],
  });
}
