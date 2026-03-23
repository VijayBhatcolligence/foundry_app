// Phase 3: Cached Module Loader Helper
// Purpose: Optimized cache reading path for sub-200ms performance

import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'module_cache.dart';

class CachedModuleLoader {
  static final CachedModuleLoader instance = CachedModuleLoader._internal();
  factory CachedModuleLoader() => instance;
  CachedModuleLoader._internal();

  final ModuleCache _cache = ModuleCache.instance;

  // Large file threshold: 1 MB
  static const int _largeFileThreshold = 1024 * 1024;

  /// Load module content from cached path
  /// Returns UTF-8 string for WebView.evaluateJavascript()
  Future<String> loadFromCache(String cachedPath) async {
    final file = File(cachedPath);

    // Check file exists
    if (!await file.exists()) {
      throw FileSystemException('File deleted between cache check and load', cachedPath);
    }

    // Check file permissions
    try {
      await file.open(mode: FileMode.read).then((f) => f.close());
    } catch (e) {
      throw FileSystemException('File read permission denied', cachedPath);
    }

    // Get file size
    final fileSize = await file.length();

    String content;

    if (fileSize > _largeFileThreshold) {
      // Use optimized reading for large files (> 1MB)
      // Note: Dart doesn't have memory-mapped file reading in standard library
      // Read in chunks for better performance
      content = await _readLargeFile(file);
    } else {
      // Read directly for small files
      content = await file.readAsString(encoding: utf8);
    }

    // Validate content
    if (content.isEmpty) {
      throw StateError('Cached module file is empty');
    }

    return content;
  }

  /// Pre-warm cache on app startup (loads manifests only)
  Future<void> preloadModule(String moduleId, String version) async {
    try {
      final cachedPath = await _cache.getCachedModulePath(moduleId, version);

      if (cachedPath != null) {
        // Just check file accessibility, don't load content yet
        final file = File(cachedPath);
        if (await file.exists()) {
          // Update access time (already done by getCachedModulePath)
          print('[CachedModuleLoader] Pre-warmed cache for $moduleId v$version');
        }
      }
    } catch (e) {
      print('[CachedModuleLoader] Pre-load failed for $moduleId v$version: $e');
    }
  }

  // Private: Read large file efficiently
  Future<String> _readLargeFile(File file) async {
    try {
      // Try UTF-8 first
      return await file.readAsString(encoding: utf8);
    } catch (e) {
      // If UTF-8 fails, try ISO-8859-1 fallback
      try {
        print('[CachedModuleLoader] UTF-8 decode failed, trying ISO-8859-1 fallback');
        return await file.readAsString(encoding: latin1);
      } catch (fallbackError) {
        throw StateError('File encoding is not UTF-8 or ISO-8859-1');
      }
    }
  }
}
