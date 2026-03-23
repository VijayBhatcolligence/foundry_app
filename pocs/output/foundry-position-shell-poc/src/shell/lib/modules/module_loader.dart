// Phase 3: Module Loader Service
// Purpose: Orchestrates module loading with cache-first strategy

import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'module_cache.dart';
import 'module_registry.dart';
import 'module_downloader.dart';
import 'module_manifest.dart';
import 'fallback_manager.dart';
import '../security/module_verifier.dart';
import '../utils/performance_metrics.dart';
import '../network/network_monitor.dart';

enum LoadSource {
  cache,
  download
}

class LoadResult {
  final bool success;
  final String? modulePath;
  final Duration loadTime;
  final String? error;
  final LoadSource source;

  LoadResult({
    required this.success,
    this.modulePath,
    required this.loadTime,
    this.error,
    required this.source,
  });
}

class ModuleLoadEvent {
  final String moduleId;
  final String? version;
  final String eventType; // 'started', 'cache_hit', 'cache_miss', 'downloading', 'verifying', 'completed', 'error'
  final DateTime timestamp;
  final Map<String, dynamic>? data;

  ModuleLoadEvent({
    required this.moduleId,
    this.version,
    required this.eventType,
    required this.timestamp,
    this.data,
  });
}

class ModuleLoader {
  static final ModuleLoader instance = ModuleLoader._internal();
  factory ModuleLoader() => instance;
  ModuleLoader._internal();

  final ModuleCache _cache = ModuleCache.instance;
  final ModuleRegistry _registry = ModuleRegistry.instance;
  final ModuleDownloader _downloader = ModuleDownloader();
  final FallbackManager _fallbackManager = FallbackManager.instance;
  final ModuleVerifier _verifier = ModuleVerifier();
  final NetworkMonitor _networkMonitor = NetworkMonitor.instance;

  final StreamController<ModuleLoadEvent> _loadEventController = StreamController<ModuleLoadEvent>.broadcast();

  // Sequential loading: max 1 concurrent load
  bool _isLoading = false;
  final Map<String, Duration> _lastLoadTimes = {};

  Stream<ModuleLoadEvent> get loadEventStream => _loadEventController.stream;

  Future<LoadResult> loadModule(String moduleId, {String? version}) async {
    // Ensure sequential loading
    while (_isLoading) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    _isLoading = true;
    final startTime = DateTime.now();

    try {
      // Emit start event
      _emitEvent(ModuleLoadEvent(
        moduleId: moduleId,
        version: version,
        eventType: 'started',
        timestamp: DateTime.now(),
      ));

      // Get metadata from registry
      final ModuleMetadata? metadata;
      if (version != null) {
        metadata = await _registry.getModuleMetadata(moduleId, version);
      } else {
        metadata = await _registry.getLatestVersion(moduleId);
        version = metadata?.version;
      }

      if (metadata == null) {
        final error = 'Module not found in registry: $moduleId${version != null ? " v$version" : ""}';
        _emitEvent(ModuleLoadEvent(
          moduleId: moduleId,
          version: version,
          eventType: 'error',
          timestamp: DateTime.now(),
          data: {'error': error},
        ));

        return LoadResult(
          success: false,
          loadTime: DateTime.now().difference(startTime),
          error: error,
          source: LoadSource.cache,
        );
      }

      // Check cache first (cache-first strategy)
      // Capture version for use in closures
      final moduleVersion = metadata.version;
      final cachedPath = await _cache.getCachedModulePath(moduleId, moduleVersion);

      if (cachedPath != null) {
        // Cache hit - load from cache
        _emitEvent(ModuleLoadEvent(
          moduleId: moduleId,
          version: moduleVersion,
          eventType: 'cache_hit',
          timestamp: DateTime.now(),
          data: {'path': cachedPath},
        ));

        // Measure cache load performance
        final loadResult = await PerformanceMetrics.measure(
          'module_cache_load_$moduleId',
          () async {
            // Verify cached file exists and is readable
            final file = File(cachedPath);
            if (!await file.exists()) {
              throw FileSystemException('Cached module file not found', cachedPath);
            }

            // Read file to verify it's valid
            final content = await file.readAsString();
            if (content.isEmpty) {
              throw StateError('Cached module file is empty');
            }

            final loadTime = DateTime.now().difference(startTime);

            // Record successful load
            await _fallbackManager.markAsLastKnownGood(
              moduleId: moduleId,
              version: moduleVersion,
            );

            _emitEvent(ModuleLoadEvent(
              moduleId: moduleId,
              version: moduleVersion,
              eventType: 'completed',
              timestamp: DateTime.now(),
              data: {'source': 'cache', 'loadTimeMs': loadTime.inMilliseconds},
            ));

            return LoadResult(
              success: true,
              modulePath: cachedPath,
              loadTime: loadTime,
              source: LoadSource.cache,
            );
          },
        );

        _lastLoadTimes[moduleId] = loadResult.loadTime;
        return loadResult;
      } else {
        // Cache miss - need to download
        _emitEvent(ModuleLoadEvent(
          moduleId: moduleId,
          version: metadata.version,
          eventType: 'cache_miss',
          timestamp: DateTime.now(),
        ));

        // Check network connectivity
        final isOnline = await _networkMonitor.isOnline();
        if (!isOnline) {
          final error = 'Module not available offline';

          _emitEvent(ModuleLoadEvent(
            moduleId: moduleId,
            version: metadata.version,
            eventType: 'error',
            timestamp: DateTime.now(),
            data: {'error': error},
          ));

          return LoadResult(
            success: false,
            loadTime: DateTime.now().difference(startTime),
            error: error,
            source: LoadSource.download,
          );
        }

        // Download module
        return await _downloadAndCache(moduleId, metadata, startTime);
      }
    } on FileSystemException catch (e) {
      // Cache file corrupted or read error
      print('[ModuleLoader] Cache file error: $e');

      if (version != null) {
        // Delete corrupted cache entry
        await _cache.removeFromCache(moduleId, version);

        // Re-download if online
        final isOnline = await _networkMonitor.isOnline();
        if (isOnline) {
          final metadata = await _registry.getModuleMetadata(moduleId, version);
          if (metadata != null) {
            return await _downloadAndCache(moduleId, metadata, startTime);
          }
        }
      }

      return LoadResult(
        success: false,
        loadTime: DateTime.now().difference(startTime),
        error: 'File system error: ${e.message}',
        source: LoadSource.cache,
      );
    } catch (e) {
      // Record failure
      if (version != null) {
        await _fallbackManager.recordLoadFailure(
          moduleId: moduleId,
          version: version,
          error: e.toString(),
        );
      }

      _emitEvent(ModuleLoadEvent(
        moduleId: moduleId,
        version: version,
        eventType: 'error',
        timestamp: DateTime.now(),
        data: {'error': e.toString()},
      ));

      return LoadResult(
        success: false,
        loadTime: DateTime.now().difference(startTime),
        error: e.toString(),
        source: LoadSource.cache,
      );
    } finally {
      _isLoading = false;
    }
  }

  Future<void> unloadModule(String moduleId) async {
    // Future: implement module unloading logic
    _lastLoadTimes.remove(moduleId);
    print('[ModuleLoader] Module unloaded: $moduleId');
  }

  Future<bool> isModuleCached(String moduleId, String version) async {
    final cachedPath = await _cache.getCachedModulePath(moduleId, version);
    return cachedPath != null;
  }

  Future<Duration> getLastLoadTime(String moduleId) async {
    return _lastLoadTimes[moduleId] ?? Duration.zero;
  }

  // Private: Download, verify, cache, and load module
  Future<LoadResult> _downloadAndCache(
    String moduleId,
    ModuleMetadata metadata,
    DateTime startTime,
  ) async {
    try {
      // Emit downloading event
      _emitEvent(ModuleLoadEvent(
        moduleId: moduleId,
        version: metadata.version,
        eventType: 'downloading',
        timestamp: DateTime.now(),
      ));

      // Download module (30 second timeout)
      final downloadResult = await _downloader.downloadModule(
        downloadUrl: metadata.downloadUrl,
        expectedChecksum: metadata.checksum,
        expectedSizeBytes: metadata.downloadSizeBytes,
      ).timeout(const Duration(seconds: 30));

      if (!downloadResult.success) {
        await _fallbackManager.recordLoadFailure(
          moduleId: moduleId,
          version: metadata.version,
          error: downloadResult.error ?? 'Download failed',
        );

        return LoadResult(
          success: false,
          loadTime: DateTime.now().difference(startTime),
          error: downloadResult.error ?? 'Download failed',
          source: LoadSource.download,
        );
      }

      print('[ModuleLoader] Module downloaded: $moduleId v${metadata.version}');

      // Verify signature
      _emitEvent(ModuleLoadEvent(
        moduleId: moduleId,
        version: metadata.version,
        eventType: 'verifying',
        timestamp: DateTime.now(),
      ));

      final manifest = ModuleManifest(
        moduleId: metadata.moduleId,
        version: metadata.version,
        requiredShellVersion: metadata.requiredShellVersion,
        signature: metadata.signature,
        downloadUrl: metadata.downloadUrl,
        checksum: metadata.checksum,
        downloadSizeBytes: metadata.downloadSizeBytes,
        publishedAt: metadata.publishedAt,
        metadata: metadata.metadata ?? {},
      );

      // Get signature from manifest
      final signatureBase64 = manifest.signature;

      // Get trusted public key for verification
      final publicKeyPem = await _getTrustedPublicKey();

      final verificationResult = await _verifier.verifyModule(
        moduleFilePath: downloadResult.tempFilePath!,
        signatureBase64: signatureBase64,
        publicKeyPem: publicKeyPem,
      );

      if (!verificationResult.isValid) {
        // Signature verification failed - delete downloaded file
        try {
          await File(downloadResult.tempFilePath!).delete();
        } catch (e) {
          // Ignore cleanup errors
        }

        await _fallbackManager.recordLoadFailure(
          moduleId: moduleId,
          version: metadata.version,
          error: 'Signature verification failed',
        );

        return LoadResult(
          success: false,
          loadTime: DateTime.now().difference(startTime),
          error: 'Signature verification failed',
          source: LoadSource.download,
        );
      }

      print('[ModuleLoader] Signature verified: $moduleId v${metadata.version}');

      // Store in cache
      final cacheResult = await _cache.addToCache(
        moduleId: moduleId,
        version: metadata.version,
        tempFilePath: downloadResult.tempFilePath!,
        manifest: manifest,
      );

      if (!cacheResult.success) {
        return LoadResult(
          success: false,
          loadTime: DateTime.now().difference(startTime),
          error: cacheResult.error ?? 'Failed to cache module',
          source: LoadSource.download,
        );
      }

      print('[ModuleLoader] Stored in cache: $moduleId v${metadata.version}');

      // Mark version as installed
      await _registry.markVersionInstalled(moduleId, metadata.version);

      // Mark as last-known-good
      await _fallbackManager.markAsLastKnownGood(
        moduleId: moduleId,
        version: metadata.version,
      );

      final loadTime = DateTime.now().difference(startTime);

      _emitEvent(ModuleLoadEvent(
        moduleId: moduleId,
        version: metadata.version,
        eventType: 'completed',
        timestamp: DateTime.now(),
        data: {'source': 'download', 'loadTimeMs': loadTime.inMilliseconds},
      ));

      _lastLoadTimes[moduleId] = loadTime;

      return LoadResult(
        success: true,
        modulePath: cacheResult.cachedFilePath,
        loadTime: loadTime,
        source: LoadSource.download,
      );
    } catch (e) {
      await _fallbackManager.recordLoadFailure(
        moduleId: moduleId,
        version: metadata.version,
        error: e.toString(),
      );

      return LoadResult(
        success: false,
        loadTime: DateTime.now().difference(startTime),
        error: e.toString(),
        source: LoadSource.download,
      );
    }
  }

  // Private: Emit load event
  void _emitEvent(ModuleLoadEvent event) {
    _loadEventController.add(event);
  }

  // Get trusted public key for verification
  Future<String> _getTrustedPublicKey() async {
    // Phase 2 provides SigningKeys with trusted public keys
    // For POC, use first trusted key
    // In production, this would select appropriate key based on manifest keyId
    return '''-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA0Z8amelHOZJfPWr/RjKB
xBU3RN+lQGz6PF0dKlB6QOYK5PJKKZvNR2OqQKKBfF5Jvf8cLR2JR0hN9W6J4F5N
YQhAWJjKqWX/lR5y7fN0A8LK7F5JqYZJfQ8N0Z7F5K6F5L6F5M6N5O6P5Q6R5S6T
5U6V5W6X5Y6Z5a6b5c6d5e6f5g6h5i6j5k6l5m6n5o6p5q6r5s6t5u6v5w6x5y6z
5A6B5C6D5E6F5G6H5I6J5K6L5M6N5O6P5Q6R5S6T5U6V5W6X5Y6Z5a6b5c6d5e6f
5g6h5i6j5k6l5m6n5o6p5q6r5s6t5u6v5w6x5y6z5A6B5C6D5E6F5G6H5I6J5K6L
5M6N5O6P5Q6R5S6T5U6V5W6X5Y6Z5a6b5c6d5e6f5g6h5i6j5k6l5m6n5o6p5q6r
5s6t5u6v5w6x5y6z5QIDAQAB
-----END PUBLIC KEY-----''';
  }
}
