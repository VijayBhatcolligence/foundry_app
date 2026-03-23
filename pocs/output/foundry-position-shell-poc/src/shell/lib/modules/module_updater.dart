// D2.2: Module Updater Service
// Purpose: Orchestrate complete update flow with state machine

import 'dart:async';
import 'module_registry.dart';
import 'module_downloader.dart';
import 'module_manifest.dart';
import 'module_cache.dart';
import 'fallback_manager.dart';
import '../security/module_verifier.dart';
import '../security/signing_keys.dart';

class ModuleUpdater {
  static final ModuleUpdater instance = ModuleUpdater._internal();
  factory ModuleUpdater() => instance;
  ModuleUpdater._internal();

  // Update state storage: moduleId -> UpdateState
  final Map<String, UpdateState> _updateStates = {};

  // Background check interval: 4 hours
  static const Duration _backgroundCheckInterval = Duration(hours: 4);
  Timer? _backgroundTimer;

  // Event stream
  final _eventStreamController = StreamController<UpdateEvent>.broadcast();

  // Check for updates for specific module, returns update info if available
  Future<UpdateCheckResult> checkForUpdates(String moduleId) async {
    final checkedAt = DateTime.now();

    try {
      // Get current installed version
      final currentVersion = await ModuleRegistry.instance.getInstalledVersion(moduleId);

      // Get latest version from registry
      final latest = await ModuleRegistry.instance.getLatestVersion(moduleId);

      if (latest == null) {
        return UpdateCheckResult(
          updateAvailable: false,
          currentVersion: currentVersion,
          error: 'Module not found in registry',
          checkedAt: checkedAt,
        );
      }

      // Check if update available
      final updateAvailable = currentVersion == null || currentVersion != latest.version;

      return UpdateCheckResult(
        updateAvailable: updateAvailable,
        latestVersion: latest.version,
        currentVersion: currentVersion,
        checkedAt: checkedAt,
      );
    } catch (e) {
      return UpdateCheckResult(
        updateAvailable: false,
        error: e.toString().contains('Network') ? 'Network unavailable' : e.toString(),
        checkedAt: checkedAt,
      );
    }
  }

  // Check all installed modules for updates
  Future<Map<String, UpdateCheckResult>> checkAllModulesForUpdates() async {
    // Get all available modules
    final allModules = await ModuleRegistry.instance.getAvailableModules();

    final results = <String, UpdateCheckResult>{};

    for (final module in allModules) {
      // Skip modules currently being updated
      final state = getUpdateState(module.moduleId);
      if (state.status == UpdateStatus.downloading ||
          state.status == UpdateStatus.verifying ||
          state.status == UpdateStatus.installing) {
        continue;
      }

      final result = await checkForUpdates(module.moduleId);
      results[module.moduleId] = result;
    }

    return results;
  }

  // Install specific module version (download → verify → cache)
  Future<InstallResult> installUpdate({
    required String moduleId,
    required String version,
    void Function(UpdateProgress)? onProgress,
  }) async {
    final startTime = DateTime.now();

    // Check if update already in progress
    final currentState = getUpdateState(moduleId);
    if (currentState.status == UpdateStatus.downloading ||
        currentState.status == UpdateStatus.verifying ||
        currentState.status == UpdateStatus.installing) {
      return InstallResult(
        success: false,
        error: 'Update already in progress',
        installDuration: DateTime.now().difference(startTime),
      );
    }

    try {
      // Get module metadata
      final metadata = await ModuleRegistry.instance.getModuleMetadata(moduleId, version);
      if (metadata == null) {
        return InstallResult(
          success: false,
          error: 'Module version not found in registry',
          installDuration: DateTime.now().difference(startTime),
        );
      }

      // Set state to downloading
      _updateState(moduleId, UpdateStatus.downloading, version, null);
      _emitEvent(UpdateEventType.downloadStarted, moduleId, version);

      // Download module
      final downloader = ModuleDownloader();
      final downloadResult = await downloader.downloadModule(
        downloadUrl: metadata.downloadUrl,
        expectedChecksum: metadata.checksum,
        expectedSizeBytes: metadata.downloadSizeBytes,
        onProgress: (progress) {
          _updateProgress(
            moduleId,
            UpdateStatus.downloading,
            progress.percentComplete * 0.7, // Download is 0-70%
            'Downloading ${progress.bytesDownloaded}/${progress.totalBytes} bytes',
          );
          _emitEvent(UpdateEventType.downloadProgress, moduleId, version, {
            'percentComplete': progress.percentComplete * 0.7,
          });
          onProgress?.call(UpdateProgress(
            currentPhase: UpdateStatus.downloading,
            percentComplete: progress.percentComplete * 0.7,
            currentOperation: 'Downloading ${progress.bytesDownloaded}/${progress.totalBytes} bytes',
          ));
        },
      );

      if (!downloadResult.success) {
        _updateState(moduleId, UpdateStatus.failed, version, downloadResult.error);
        _emitEvent(UpdateEventType.installFailed, moduleId, version, {'error': downloadResult.error});
        return InstallResult(
          success: false,
          error: downloadResult.error,
          installDuration: DateTime.now().difference(startTime),
        );
      }

      _emitEvent(UpdateEventType.downloadComplete, moduleId, version);

      // Verify signature
      _updateState(moduleId, UpdateStatus.verifying, version, null);
      _updateProgress(moduleId, UpdateStatus.verifying, 70.0, 'Verifying signature');
      _emitEvent(UpdateEventType.verificationStarted, moduleId, version);

      final verifier = ModuleVerifier();
      final verifyResult = await verifier.verifyModule(
        moduleFilePath: downloadResult.tempFilePath!,
        signatureBase64: metadata.signature,
        publicKeyPem: SigningKeys.primaryPublicKeyPem,
      );

      if (!verifyResult.isValid) {
        _updateState(moduleId, UpdateStatus.failed, version, verifyResult.error);
        _emitEvent(UpdateEventType.installFailed, moduleId, version, {'error': verifyResult.error});
        return InstallResult(
          success: false,
          error: verifyResult.error,
          installDuration: DateTime.now().difference(startTime),
        );
      }

      _updateProgress(moduleId, UpdateStatus.verifying, 90.0, 'Signature verified');
      _emitEvent(UpdateEventType.verificationComplete, moduleId, version);

      // Install to cache
      _updateState(moduleId, UpdateStatus.installing, version, null);
      _updateProgress(moduleId, UpdateStatus.installing, 90.0, 'Installing to cache');
      _emitEvent(UpdateEventType.installStarted, moduleId, version);

      final cache = ModuleCache.instance;
      final manifest = ModuleManifest(
        moduleId: metadata.moduleId,
        version: metadata.version,
        requiredShellVersion: metadata.requiredShellVersion,
        signature: metadata.signature,
        downloadUrl: metadata.downloadUrl,
        checksum: metadata.checksum,
        downloadSizeBytes: metadata.downloadSizeBytes,
        publishedAt: metadata.publishedAt,
        metadata: metadata.metadata,
      );

      final cacheResult = await cache.addToCache(
        moduleId: moduleId,
        version: version,
        tempFilePath: downloadResult.tempFilePath!,
        manifest: manifest,
      );

      if (!cacheResult.success) {
        _updateState(moduleId, UpdateStatus.failed, version, cacheResult.error);
        _emitEvent(UpdateEventType.installFailed, moduleId, version, {'error': cacheResult.error});
        return InstallResult(
          success: false,
          error: cacheResult.error,
          installDuration: DateTime.now().difference(startTime),
        );
      }

      // Mark as installed in registry
      await ModuleRegistry.instance.markVersionInstalled(moduleId, version);

      // Mark as last-known-good
      await FallbackManager.instance.markAsLastKnownGood(
        moduleId: moduleId,
        version: version,
      );

      // Update state to complete
      _updateState(moduleId, UpdateStatus.complete, version, null);
      _updateProgress(moduleId, UpdateStatus.complete, 100.0, 'Installation complete');
      _emitEvent(UpdateEventType.installComplete, moduleId, version);

      return InstallResult(
        success: true,
        installedVersion: version,
        installDuration: DateTime.now().difference(startTime),
      );
    } catch (e) {
      _updateState(moduleId, UpdateStatus.failed, version, e.toString());
      _emitEvent(UpdateEventType.installFailed, moduleId, version, {'error': e.toString()});
      print('Error installing module update: $e');
      return InstallResult(
        success: false,
        error: e.toString(),
        installDuration: DateTime.now().difference(startTime),
      );
    }
  }

  // Cancel in-progress update installation
  Future<void> cancelUpdate(String moduleId) async {
    final state = getUpdateState(moduleId);

    if (state.status == UpdateStatus.downloading) {
      // Cancel download
      final metadata = await ModuleRegistry.instance.getModuleMetadata(moduleId, state.targetVersion!);
      if (metadata != null) {
        final downloader = ModuleDownloader();
        await downloader.cancelDownload(metadata.downloadUrl);
      }
    }

    _updateState(moduleId, UpdateStatus.cancelled, state.targetVersion, null);
    _emitEvent(UpdateEventType.updateCancelled, moduleId, state.targetVersion);
  }

  // Get current update state for module
  UpdateState getUpdateState(String moduleId) {
    return _updateStates[moduleId] ??
        UpdateState(
          moduleId: moduleId,
          status: UpdateStatus.idle,
          lastUpdated: DateTime.now(),
        );
  }

  // Start background update checker (checks every 4 hours)
  void startBackgroundUpdateChecker() {
    if (_backgroundTimer != null && _backgroundTimer!.isActive) {
      return; // Already running
    }

    // First check after 30 seconds
    Future.delayed(const Duration(seconds: 30), () async {
      await _performBackgroundCheck();
    });

    // Then check every 4 hours
    _backgroundTimer = Timer.periodic(_backgroundCheckInterval, (timer) async {
      await _performBackgroundCheck();
    });
  }

  // Stop background update checker
  void stopBackgroundUpdateChecker() {
    _backgroundTimer?.cancel();
    _backgroundTimer = null;
  }

  // Stream of update events
  Stream<UpdateEvent> get updateEventStream => _eventStreamController.stream;

  // Private helper: Perform background update check
  Future<void> _performBackgroundCheck() async {
    try {
      final results = await checkAllModulesForUpdates();

      for (final entry in results.entries) {
        if (entry.value.updateAvailable) {
          _emitEvent(
            UpdateEventType.updateAvailable,
            entry.key,
            entry.value.latestVersion,
            {'currentVersion': entry.value.currentVersion},
          );
        }
      }
    } catch (e) {
      print('Background update check failed: $e');
    }
  }

  // Private helper: Update state
  void _updateState(String moduleId, UpdateStatus status, String? targetVersion, String? error) {
    _updateStates[moduleId] = UpdateState(
      moduleId: moduleId,
      status: status,
      targetVersion: targetVersion,
      error: error,
      lastUpdated: DateTime.now(),
    );
  }

  // Private helper: Update progress
  void _updateProgress(String moduleId, UpdateStatus status, double percent, String operation) {
    final state = _updateStates[moduleId];
    if (state != null) {
      _updateStates[moduleId] = UpdateState(
        moduleId: moduleId,
        status: status,
        targetVersion: state.targetVersion,
        progress: UpdateProgress(
          currentPhase: status,
          percentComplete: percent,
          currentOperation: operation,
        ),
        error: state.error,
        lastUpdated: DateTime.now(),
      );
    }
  }

  // Private helper: Emit event
  void _emitEvent(UpdateEventType type, String moduleId, String? version, [Map<String, dynamic>? data]) {
    _eventStreamController.add(UpdateEvent(
      type: type,
      moduleId: moduleId,
      version: version,
      data: data ?? {},
      timestamp: DateTime.now(),
    ));
  }
}

class UpdateCheckResult {
  final bool updateAvailable;
  final String? latestVersion;
  final String? currentVersion;
  final String? error;
  final DateTime checkedAt;

  UpdateCheckResult({
    required this.updateAvailable,
    this.latestVersion,
    this.currentVersion,
    this.error,
    required this.checkedAt,
  });
}

class InstallResult {
  final bool success;
  final String? installedVersion;
  final String? error;
  final Duration installDuration;

  InstallResult({
    required this.success,
    this.installedVersion,
    this.error,
    required this.installDuration,
  });
}

class UpdateState {
  final String moduleId;
  final UpdateStatus status;
  final String? targetVersion;
  final UpdateProgress? progress;
  final String? error;
  final DateTime lastUpdated;

  UpdateState({
    required this.moduleId,
    required this.status,
    this.targetVersion,
    this.progress,
    this.error,
    required this.lastUpdated,
  });
}

enum UpdateStatus {
  idle,
  checking,
  available,
  downloading,
  verifying,
  installing,
  complete,
  failed,
  cancelled,
}

class UpdateProgress {
  final UpdateStatus currentPhase;
  final double percentComplete;
  final String? currentOperation;

  UpdateProgress({
    required this.currentPhase,
    required this.percentComplete,
    this.currentOperation,
  });
}

class UpdateEvent {
  final UpdateEventType type;
  final String moduleId;
  final String? version;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  UpdateEvent({
    required this.type,
    required this.moduleId,
    this.version,
    this.data = const {},
    required this.timestamp,
  });
}

enum UpdateEventType {
  updateAvailable,
  downloadStarted,
  downloadProgress,
  downloadComplete,
  verificationStarted,
  verificationComplete,
  installStarted,
  installComplete,
  installFailed,
  updateCancelled,
}
