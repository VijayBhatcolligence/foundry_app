# Phase 2 Trust & Delivery — VALIDATED SPECIFICATION

## Metadata

**PHASE_ID**: `phase-2-trust-delivery`
**PHASE_NAME**: Trust & Delivery — Module Update System
**VALIDATED**: 2026-03-14
**VALIDATOR_CYCLE**: 2
**VALIDATOR_DOC_VERSION**: 6.0.0
**DRIFT_CHECK_STATUS**: APPLIED_PATCHES

---

## What To Build

Phase 2 builds a complete module update delivery system that enables position modules to be updated dynamically without requiring Flutter shell reinstallation. This system implements cryptographic signature verification using RSA-2048, semantic version compatibility checking between modules and shell, atomic download-verify-install operations with SHA-256 checksums, and automatic fallback to last-known-good versions when module loads fail. The update system maintains strict security boundaries by verifying all module code before execution, enforces compatibility constraints to prevent runtime errors from version mismatches, and provides resilient rollback mechanisms to ensure users always have working modules even when updates fail. This phase establishes the foundation for safe, continuous module delivery while maintaining the security architecture established in Phase 1.

---

## File Manifest

All file paths are absolute from project root: `C:\Users\bijay\OneDrive\Desktop\auto_agent3\pocs\output\foundry-position-shell-poc`

| Deliverable ID | File Path | Type | Purpose |
|----------------|-----------|------|---------|
| D1.1 | `src/shell/lib/modules/module_manifest.dart` | Dart Class | Module metadata structure and manifest parsing |
| D1.2 | `src/shell/lib/modules/module_registry.dart` | Dart Service Class | Module registry with version tracking |
| D2.1 | `src/shell/lib/modules/module_downloader.dart` | Dart Service Class | HTTP download with progress and retry |
| D2.2 | `src/shell/lib/modules/module_updater.dart` | Dart Service Class | Update orchestration state machine |
| D3.1 | `src/shell/lib/security/module_verifier.dart` | Dart Service Class | RSA signature verification |
| D3.2 | `src/shell/lib/security/signing_keys.dart` | Dart Class | Public key storage and validation |
| D4.1 | `src/shell/lib/modules/compatibility_checker.dart` | Dart Service Class | Version compatibility validation |
| D4.2 | `src/shell/lib/modules/version_resolver.dart` | Dart Service Class | Semantic version comparison |
| D5.1 | `src/shell/lib/modules/module_cache.dart` | Dart Service Class | Cache directory and size management |
| D5.2 | `src/shell/lib/modules/fallback_manager.dart` | Dart Service Class | Automatic rollback to last-known-good |
| D6.1 | `src/runtime-host/module-loader.js` | JavaScript Module | Dynamic module loading from cache |
| D6.2 | `src/runtime-host/update-notification.js` | JavaScript Module | Update UI notification component |
| D7.1 | `src/shell/lib/bridge/module_bridge_extension.dart` | Dart Class | Bridge methods for module management |
| D8.1 | `tests/modules/version_compatibility_test.dart` | Dart Test | Semantic version validation tests |
| D8.2 | `tests/modules/signature_verification_test.dart` | Dart Test | RSA signature verification tests |
| D8.3 | `tests/modules/update_flow_test.dart` | Dart Test | Update orchestration tests |
| D8.4 | `tests/modules/fallback_test.dart` | Dart Test | Automatic rollback tests |
| D8.5 | `tests/integration/module_update_integration_test.dart` | Dart Test | End-to-end update scenarios |
| D8.6 | `tests/modules/module_manifest_test.dart` | Dart Test | Manifest parsing tests |
| D8.7 | `tests/modules/module_download_test.dart` | Dart Test | Download and checksum tests |
| D8.8 | `tests/modules/update_check_test.dart` | Dart Test | Update detection tests |
| D8.9 | `tests/modules/last_known_good_test.dart` | Dart Test | Last-known-good persistence tests |
| D8.10 | `tests/modules/compatibility_rejection_test.dart` | Dart Test | Incompatible version rejection tests |
| D8.11 | `tests/modules/module_cache_test.dart` | Dart Test | Multi-version cache tests |
| D8.12 | `tests/integration/update_notification_test.dart` | Dart Test | Update UI notification tests |
| D8.13 | `tests/integration/cached_module_load_test.dart` | Dart Test | Cache load performance tests |
| D9.1 | `src/modules/sample-warehouse/module.manifest.json` | JSON | Module metadata v1.1.0 |
| D9.2 | `src/modules/sample-warehouse-v1.1.0/index.tsx` | TypeScript/React | Updated module version |
| D9.3 | `src/modules/sample-warehouse-v1.1.0/package.json` | JSON | Module dependencies v1.1.0 |

---

## Deliverables

### D1.1: Module Manifest Structure

**Type**: Dart Class
**File**: `src/shell/lib/modules/module_manifest.dart`
**Purpose**: Parse and validate module metadata from JSON manifests

**Interface**:
```dart
class ModuleManifest {
  final String moduleId;
  final String version;
  final String requiredShellVersion;
  final String signature;
  final String downloadUrl;
  final String checksum;
  final int downloadSizeBytes;
  final DateTime publishedAt;
  final Map<String, dynamic> metadata;

  ModuleManifest({
    required this.moduleId,
    required this.version,
    required this.requiredShellVersion,
    required this.signature,
    required this.downloadUrl,
    required this.checksum,
    required this.downloadSizeBytes,
    required this.publishedAt,
    this.metadata = const {},
  });

  factory ModuleManifest.fromJson(Map<String, dynamic> json);
  Map<String, dynamic> toJson();

  // Validation result with detailed error information
  ManifestValidationResult validate();
}

class ManifestValidationResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;

  ManifestValidationResult({
    required this.isValid,
    this.errors = const [],
    this.warnings = const [],
  });
}
```

**Data Structures**:
- `moduleId`: String matching pattern `^[a-z][a-z0-9-]{2,63}$` (lowercase alphanumeric + hyphens, 3-64 chars)
- `version`: String in semantic version format `MAJOR.MINOR.PATCH` (e.g., "1.2.3", no pre-release tags in Phase 2)
- `requiredShellVersion`: String in semantic version range format using caret notation `^MAJOR.MINOR.PATCH` (e.g., "^1.0.0" means >=1.0.0 <2.0.0)
- `signature`: Base64-encoded string of RSA-2048 signature (344 characters when base64-encoded)
- `downloadUrl`: Valid HTTPS URL string (must start with "https://", max 2048 characters)
- `checksum`: 64-character lowercase hexadecimal string (SHA-256 hash)
- `downloadSizeBytes`: Integer > 0 and <= 52428800 (50 MB max module size)
- `publishedAt`: ISO-8601 datetime string (e.g., "2026-03-14T10:30:00Z")
- `metadata`: Optional JSON object with keys: `changelog` (string), `minOSVersion` (string), `deprecationWarning` (string)

**Constraints**:
- Manifest JSON must not exceed 32KB in size
- All required fields must be present (fromJson throws `FormatException` if missing)
- `moduleId` must match regex pattern (validated in `validate()` method)
- `version` must parse with `semantic_version` package (validated in `validate()`)
- `requiredShellVersion` must be valid semver range (validated in `validate()`)
- `signature` must be valid base64 with length 344 characters (validated in `validate()`)
- `checksum` must be 64 hex characters matching pattern `^[a-f0-9]{64}$` (validated in `validate()`)
- `downloadUrl` must pass `Uri.parse()` and use HTTPS scheme (validated in `validate()`)
- `downloadSizeBytes` must be in range 1 to 52428800 (validated in `validate()`)
- `publishedAt` must parse as valid ISO-8601 datetime (validated in `validate()`)

**Edge Cases**:
1. **Empty manifest JSON**: `fromJson({})` throws `FormatException` with message "Missing required field: moduleId"
2. **Invalid moduleId format**: `validate()` returns `isValid=false` with error "moduleId must match pattern ^[a-z][a-z0-9-]{2,63}$"
3. **Invalid version format**: `validate()` returns `isValid=false` with error "version must be valid semantic version (MAJOR.MINOR.PATCH)"
4. **HTTP (non-HTTPS) downloadUrl**: `validate()` returns `isValid=false` with error "downloadUrl must use HTTPS scheme"
5. **Checksum wrong length**: `validate()` returns `isValid=false` with error "checksum must be 64 hexadecimal characters"
6. **Oversized module**: `validate()` returns `isValid=false` with error "downloadSizeBytes exceeds maximum 52428800 (50 MB)"
7. **Future publishedAt date**: `validate()` returns `isValid=false` with warning "publishedAt is in the future" but `isValid=true` (warning only)
8. **Unknown metadata fields**: Ignored (forward compatibility), no error or warning
9. **Null values in required fields**: `fromJson()` throws `FormatException` with message "Field {fieldName} cannot be null"
10. **Malformed JSON**: `fromJson()` throws `FormatException` with message from JSON parser

**Error Handling**:
- JSON parsing errors: Throw `FormatException` with descriptive message including field name
- Validation errors: Return `ManifestValidationResult` with `isValid=false` and list of error strings
- Do NOT throw exceptions from `validate()` method, always return result object
- Unknown fields in metadata: Log warning but do not fail validation

---

### D1.2: Module Registry Service

**Type**: Dart Service Class (singleton)
**File**: `src/shell/lib/modules/module_registry.dart`
**Purpose**: Track available modules, versions, and installation state

**Interface**:
```dart
class ModuleRegistry {
  static final ModuleRegistry instance = ModuleRegistry._internal();
  factory ModuleRegistry() => instance;

  // Returns null if module not found, otherwise latest compatible version
  Future<ModuleMetadata?> getLatestVersion(String moduleId);

  // Returns empty list if module not found or no cached versions
  Future<List<String>> getCachedVersions(String moduleId);

  // Returns null if not installed/cached
  Future<String?> getInstalledVersion(String moduleId);

  // Returns null if module not found in registry
  Future<ModuleMetadata?> getModuleMetadata(String moduleId, String version);

  // Returns all modules in registry (empty list if registry not loaded)
  Future<List<ModuleMetadata>> getAvailableModules();

  // Mark version as installed/cached
  Future<void> markVersionInstalled(String moduleId, String version);

  // Remove version from installed cache list
  Future<void> markVersionUninstalled(String moduleId, String version);

  // Load registry from remote manifest URL
  Future<RegistryLoadResult> loadRegistry(String registryUrl);

  // Returns true if registry has been loaded at least once
  bool get isRegistryLoaded;
}

class ModuleMetadata {
  final String moduleId;
  final String version;
  final String requiredShellVersion;
  final String downloadUrl;
  final String checksum;
  final String signature;
  final int downloadSizeBytes;
  final DateTime publishedAt;
  final bool isInstalled;
  final Map<String, dynamic> metadata;

  ModuleMetadata({
    required this.moduleId,
    required this.version,
    required this.requiredShellVersion,
    required this.downloadUrl,
    required this.checksum,
    required this.signature,
    required this.downloadSizeBytes,
    required this.publishedAt,
    required this.isInstalled,
    this.metadata = const {},
  });

  factory ModuleMetadata.fromManifest(ModuleManifest manifest, {bool isInstalled = false});
}

class RegistryLoadResult {
  final bool success;
  final int modulesLoaded;
  final String? error;
  final DateTime loadedAt;

  RegistryLoadResult({
    required this.success,
    required this.modulesLoaded,
    this.error,
    required this.loadedAt,
  });
}
```

**Data Structures**:
- Registry manifest URL: HTTPS URL pointing to JSON file containing array of `ModuleManifest` objects
- Registry JSON format: `{ "modules": [ {...ModuleManifest...}, ... ], "version": "1", "updatedAt": "ISO-8601" }`
- In-memory storage: Map of `moduleId -> List<ModuleMetadata>` sorted by version descending
- Installed versions storage: SQLite database table `installed_modules(module_id TEXT, version TEXT, installed_at INTEGER, PRIMARY KEY(module_id, version))`

**Constraints**:
- Registry must be loaded before calling `getLatestVersion()` or `getAvailableModules()` (returns null/empty if not loaded)
- `loadRegistry()` timeout: 30 seconds, after which returns `RegistryLoadResult(success: false, error: "Timeout loading registry")`
- Registry JSON max size: 5 MB (larger responses rejected with error "Registry too large")
- Maximum modules in registry: 1000 (additional modules ignored with warning logged)
- `getLatestVersion()` only returns versions compatible with current shell version (uses `CompatibilityChecker`)
- Multiple calls to `loadRegistry()` replace previous registry data (not merged)
- Registry is not persisted to disk in Phase 2 (in-memory only, reloaded on app restart)

**Edge Cases**:
1. **Registry not loaded**: `getLatestVersion()` returns `null`, `getAvailableModules()` returns `[]`, `isRegistryLoaded` returns `false`
2. **Empty registry JSON**: `loadRegistry()` returns `RegistryLoadResult(success: true, modulesLoaded: 0)`
3. **Network error during load**: Returns `RegistryLoadResult(success: false, error: "Network error: {details}")`
4. **Malformed registry JSON**: Returns `RegistryLoadResult(success: false, error: "Invalid JSON: {details}")`
5. **No compatible versions available**: `getLatestVersion()` returns `null` even if non-compatible versions exist
6. **Module not in registry but is cached**: `getInstalledVersion()` returns version string, `getLatestVersion()` returns `null`
7. **Concurrent loadRegistry calls**: Second call waits for first to complete, then replaces data
8. **Module with duplicate versions in registry**: Only first occurrence kept, others logged as warning
9. **Invalid module metadata in registry**: Module skipped, warning logged, other modules still loaded
10. **Very large version list for single module**: Only most recent 50 versions kept, older versions dropped

**Error Handling**:
- Network errors: Return `RegistryLoadResult` with `success=false` and error description
- JSON parse errors: Return `RegistryLoadResult` with `success=false` and error description
- Database errors on mark operations: Throw `StateError` with message "Failed to update module installation state: {details}"
- Timeout on registry load: Return `RegistryLoadResult` with `success=false` and error "Timeout loading registry after 30 seconds"

---

### D2.1: Module Downloader Service

**Type**: Dart Service Class
**File**: `src/shell/lib/modules/module_downloader.dart`
**Purpose**: Download module files with progress tracking, checksum validation, and retry logic

**Interface**:
```dart
class ModuleDownloader {
  // Download module to temporary location, verify checksum, return temp path
  Future<DownloadResult> downloadModule({
    required String downloadUrl,
    required String expectedChecksum,
    required int expectedSizeBytes,
    void Function(DownloadProgress)? onProgress,
  });

  // Cancel in-progress download by URL
  Future<void> cancelDownload(String downloadUrl);

  // Check if download is currently in progress for URL
  bool isDownloading(String downloadUrl);

  // Get current progress for download by URL (returns null if not downloading)
  DownloadProgress? getProgress(String downloadUrl);
}

class DownloadResult {
  final bool success;
  final String? tempFilePath;  // Absolute path to downloaded file in temp directory
  final String? error;
  final int bytesDownloaded;
  final Duration duration;
  final bool checksumValid;

  DownloadResult({
    required this.success,
    this.tempFilePath,
    this.error,
    required this.bytesDownloaded,
    required this.duration,
    required this.checksumValid,
  });
}

class DownloadProgress {
  final int bytesDownloaded;
  final int totalBytes;
  final double percentComplete;  // 0.0 to 100.0
  final Duration elapsed;
  final int bytesPerSecond;

  DownloadProgress({
    required this.bytesDownloaded,
    required this.totalBytes,
    required this.percentComplete,
    required this.elapsed,
    required this.bytesPerSecond,
  });
}
```

**Data Structures**:
- Download temporary directory: `{app_temp}/module_downloads/{moduleId}-{version}-{timestamp}.tmp`
- Checksum: 64-character lowercase hexadecimal SHA-256 hash
- Progress updates: Emitted every 256 KB downloaded or every 500ms, whichever comes first
- Retry state: In-memory map of `downloadUrl -> RetryState(attempts: int, lastError: String, nextRetryAt: DateTime)`

**Constraints**:
- Implementation must import dart:async library when using Completer, Future, Stream, TimeoutException, or other async primitives. All Dart files using async/await or async coordination types must include: import 'dart:async';
- Download timeout: 300 seconds (5 minutes) total per download attempt
- Maximum retry attempts: 3 (initial attempt + 2 retries)
- Retry backoff: Exponential with base 2 seconds (2s, 4s, 8s delays)
- Concurrent downloads: Maximum 2 simultaneous downloads, additional requests queued
- Maximum download size: 52428800 bytes (50 MB), larger downloads aborted with error
- Checksum validation: Performed after complete download, before returning success
- Atomic operations: Download to `.tmp` file, verify checksum, then return path (no rename to final location in downloader)
- Cleanup: Failed download temp files deleted immediately, successful temp files deleted after 1 hour if not moved

**Edge Cases**:
1. **Network disconnected mid-download**: After 30 seconds of no progress, retry with exponential backoff
2. **Server returns wrong Content-Length**: If actual size differs from `expectedSizeBytes` by >1%, log warning but continue
3. **Checksum mismatch**: Return `DownloadResult(success: false, checksumValid: false, error: "Checksum mismatch")`
4. **Download URL 404**: Return `DownloadResult(success: false, error: "HTTP 404: Not Found")` after 3 retry attempts
5. **Concurrent downloads of same URL**: Second request waits for first to complete, returns same result
6. **Cancel during checksum validation**: Checksum validation continues (not cancellable), then cleanup performed
7. **Disk full during download**: Return `DownloadResult(success: false, error: "Disk full")`
8. **Server returns non-HTTPS redirect**: Follow redirect if target is HTTPS, otherwise abort with error
9. **Very slow download (<1 KB/s)**: After 60 seconds of <1 KB/s, abort and retry
10. **Download size exceeds expected**: Abort when downloaded bytes exceed `expectedSizeBytes * 1.1` (10% tolerance)

**Error Handling**:
- Network errors: Retry with exponential backoff up to 3 attempts total, then return `DownloadResult` with error
- HTTP errors (4xx, 5xx): 4xx errors not retried (return immediately), 5xx errors retried up to 3 attempts
- Checksum errors: Not retried (indicates corrupted download), return immediately with `checksumValid: false`
- Timeout errors: Counted as retry attempt, uses exponential backoff
- Disk I/O errors: Not retried, return immediately with error description
- All errors return `DownloadResult(success: false)` with error string describing failure

---

### D2.2: Module Updater Service

**Type**: Dart Service Class (singleton)
**File**: `src/shell/lib/modules/module_updater.dart`
**Purpose**: Orchestrate complete update flow with state machine

**Interface**:
```dart
class ModuleUpdater {
  static final ModuleUpdater instance = ModuleUpdater._internal();
  factory ModuleUpdater() => instance;

  // Check for updates for specific module, returns update info if available
  Future<UpdateCheckResult> checkForUpdates(String moduleId);

  // Check all installed modules for updates
  Future<Map<String, UpdateCheckResult>> checkAllModulesForUpdates();

  // Install specific module version (download → verify → cache)
  Future<InstallResult> installUpdate({
    required String moduleId,
    required String version,
    void Function(UpdateProgress)? onProgress,
  });

  // Cancel in-progress update installation
  Future<void> cancelUpdate(String moduleId);

  // Get current update state for module
  UpdateState getUpdateState(String moduleId);

  // Start background update checker (checks every 4 hours)
  void startBackgroundUpdateChecker();

  // Stop background update checker
  void stopBackgroundUpdateChecker();

  // Stream of update events (new updates available, installation complete, etc)
  Stream<UpdateEvent> get updateEventStream;
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
  idle,           // No update in progress
  checking,       // Checking for updates
  available,      // Update available but not started
  downloading,    // Downloading module files
  verifying,      // Verifying signature and checksum
  installing,     // Moving to cache and marking installed
  complete,       // Installation complete successfully
  failed,         // Installation failed
  cancelled,      // Installation cancelled by user
}

class UpdateProgress {
  final UpdateStatus currentPhase;
  final double percentComplete;  // 0.0 to 100.0 across entire update process
  final String? currentOperation;  // Human-readable description

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
  updateAvailable,       // New update detected
  downloadStarted,       // Download phase started
  downloadProgress,      // Download progress update
  downloadComplete,      // Download phase complete
  verificationStarted,   // Verification phase started
  verificationComplete,  // Verification phase complete
  installStarted,        // Installation phase started
  installComplete,       // Installation complete
  installFailed,         // Installation failed
  updateCancelled,       // Update cancelled
}
```

**Data Structures**:
- Update state storage: In-memory map of `moduleId -> UpdateState`
- Background check interval: 4 hours (14400 seconds)
- Progress calculation: Download 0-70%, Verification 70-90%, Installation 90-100%
- Event stream: Broadcast stream with replay buffer of last 100 events

**Constraints**:
- Implementation must import all referenced types. The ModuleUpdater class uses ModuleManifest and must include: import 'module_manifest.dart'; General constraint: All Dart files must import types before using them. Dart analyzer will report 'The method X isn't defined for the type Y' when imports are missing.
- Only one update per module can be in progress at a time
- Attempting to start update while another is in progress returns `InstallResult(success: false, error: "Update already in progress")`
- Background checker runs on timer, first check on app launch + 30 seconds
- Background checker skips modules currently being updated
- Update installation requires successful completion of all phases: download → verify → install
- Failed verification aborts installation immediately (does not proceed to install phase)
- `installUpdate()` automatically marks module as last-known-good after successful installation
- Background checker only notifies of updates, does not auto-install

**Edge Cases**:
1. **Update check with no network**: Returns `UpdateCheckResult(updateAvailable: false, error: "Network unavailable")`
2. **Module not in registry**: Returns `UpdateCheckResult(updateAvailable: false, error: "Module not found in registry")`
3. **Current version is latest**: Returns `UpdateCheckResult(updateAvailable: false, latestVersion: currentVersion)`
4. **Cancel during download**: Download cancelled, temp files cleaned up, state set to `cancelled`
5. **Cancel during verification**: Verification completes (not cancellable), then state set to `cancelled`, temp files cleaned up
6. **Install while module is mounted**: Installation proceeds, but module reload required (emits `updateAvailable` event with `requiresReload: true`)
7. **Multiple concurrent checkAllModulesForUpdates calls**: Requests are serialized, second call waits for first to complete
8. **Background checker disabled**: `startBackgroundUpdateChecker()` called multiple times has no effect (idempotent)
9. **App backgrounded during update**: Update continues in background if OS permits, otherwise pauses and resumes on foreground
10. **Registry refresh during update**: In-progress updates continue with old registry data, new checks use new registry

**Error Handling**:
- Download errors: Set state to `failed`, emit `installFailed` event with error details
- Verification errors: Set state to `failed`, emit `installFailed` event with error details
- Installation errors: Set state to `failed`, emit `installFailed` event with error details, remove partial installation
- All errors logged to console with timestamp and full error stack
- Failed updates do NOT affect currently installed version (rollback not needed, old version still in cache)
- Update event stream never throws, errors communicated via `UpdateEvent` objects

---

### D3.1: Module Signature Verifier

**Type**: Dart Service Class
**File**: `src/shell/lib/security/module_verifier.dart`
**Purpose**: Verify RSA-2048 signatures on module files

**Interface**:
```dart
class ModuleVerifier {
  // Verify module file signature using trusted public key
  Future<VerificationResult> verifyModule({
    required String moduleFilePath,
    required String signatureBase64,
    required String publicKeyPem,
  });

  // Verify manifest signature
  Future<VerificationResult> verifyManifest({
    required ModuleManifest manifest,
    required String publicKeyPem,
  });

  // Load trusted public key and validate format
  PublicKey loadPublicKey(String publicKeyPem);
}

class VerificationResult {
  final bool isValid;
  final String? error;
  final DateTime verifiedAt;
  final String algorithm;  // e.g., "RSA-2048/SHA-256"

  VerificationResult({
    required this.isValid,
    this.error,
    required this.verifiedAt,
    required this.algorithm,
  });
}

class PublicKey {
  final String keyId;  // SHA-256 hash of PEM content (first 16 hex chars)
  final String pem;
  final int keySizeBits;
  final String algorithm;

  PublicKey({
    required this.keyId,
    required this.pem,
    required this.keySizeBits,
    required this.algorithm,
  });
}
```

**Data Structures**:
- RSA key size: 2048 bits (256 bytes)
- Signature algorithm: RSASSA-PKCS1-v1_5 with SHA-256
- Signature format: Base64-encoded string (344 characters for RSA-2048)
- Public key format: PEM format with header `-----BEGIN PUBLIC KEY-----` and footer `-----END PUBLIC KEY-----`
- Public key storage: Embedded in `signing_keys.dart` as const String
- Signature covers: SHA-256 hash of file contents for module files, or JSON string of manifest fields for manifests

**Constraints**:
- Implementation must import dart:async library when using TimeoutException, Completer, or other async error types. All Dart files implementing timeout error handling must include: import 'dart:async';
- Only RSA-2048 keys accepted (1024-bit and 4096-bit keys rejected with error)
- Only SHA-256 hash algorithm supported (other algorithms rejected)
- Signature must be exactly 344 base64 characters (for RSA-2048)
- Public key PEM must be valid format (parseable by pointycastle)
- Verification timeout: 5 seconds per verification attempt
- Module file size for verification: Maximum 52428800 bytes (50 MB)
- Manifest signature covers: Concatenated string of `moduleId|version|downloadUrl|checksum` fields

**Edge Cases**:
1. **Invalid base64 signature**: Returns `VerificationResult(isValid: false, error: "Invalid base64 signature")`
2. **Wrong signature length**: Returns `VerificationResult(isValid: false, error: "Signature length mismatch")`
3. **Tampered module file**: Returns `VerificationResult(isValid: false, error: "Signature verification failed")`
4. **Malformed PEM key**: `loadPublicKey()` throws `FormatException("Invalid PEM format")`
5. **Wrong key size (not 2048-bit)**: `loadPublicKey()` throws `FormatException("Key must be RSA-2048")`
6. **Missing module file**: Returns `VerificationResult(isValid: false, error: "Module file not found")`
7. **Empty module file**: Returns `VerificationResult(isValid: false, error: "Module file is empty")`
8. **Signature for different file**: Returns `VerificationResult(isValid: false, error: "Signature verification failed")`
9. **Expired certificate (future Phase)**: Phase 2 does NOT check expiry, future phases will add this
10. **Verification timeout**: Returns `VerificationResult(isValid: false, error: "Verification timeout after 5 seconds")`

**Error Handling**:
- File I/O errors: Return `VerificationResult(isValid: false, error: "File error: {details}")`
- Cryptographic errors: Return `VerificationResult(isValid: false, error: "Cryptographic error: {details}")`
- Timeout errors: Return `VerificationResult(isValid: false, error: "Verification timeout")`
- Invalid key format: Throw `FormatException` from `loadPublicKey()` (caller must handle)
- All verification failures return `isValid: false` with descriptive error, never throw exceptions from `verifyModule()` or `verifyManifest()`

---

### D3.2: Signing Keys Storage

**Type**: Dart Class
**File**: `src/shell/lib/security/signing_keys.dart`
**Purpose**: Store and manage trusted public keys

**Interface**:
```dart
class SigningKeys {
  // Primary trusted public key for module signing
  static const String primaryPublicKeyPem = '''
-----BEGIN PUBLIC KEY-----
{2048-bit RSA public key in PEM format}
-----END PUBLIC KEY-----
''';

  // Key rotation: Secondary key for transition period
  static const String? secondaryPublicKeyPem = null;

  // Get list of all trusted public keys
  static List<String> get trustedKeys => [
    primaryPublicKeyPem,
    if (secondaryPublicKeyPem != null) secondaryPublicKeyPem!,
  ];

  // Validate key format and size
  static bool isValidKey(String keyPem);

  // Get key identifier (first 16 chars of SHA-256 hash)
  static String getKeyId(String keyPem);
}
```

**Data Structures**:
- Public key format: PEM string with standard headers/footers
- Key ID: First 16 hexadecimal characters of SHA-256 hash of PEM content
- Key rotation: Primary key always present, secondary key used during rotation period (null otherwise)
- Key trust: All keys in `trustedKeys` list are equally trusted

**Constraints**:
- Primary key must always be non-null and valid RSA-2048 PEM
- Secondary key is optional (null when not in rotation period)
- Maximum 2 trusted keys at any time (primary + optional secondary)
- Keys are embedded at compile time (not loaded from file or network)
- Key format validation checks: PEM headers/footers present, base64 content valid, key size is 2048 bits
- `isValidKey()` returns false for keys with wrong size, malformed PEM, or invalid base64

**Edge Cases**:
1. **Invalid PEM format in primaryPublicKeyPem**: Application fails to compile (const validation error)
2. **Secondary key during rotation**: Both keys accepted for verification, new modules signed with primary only
3. **Secondary key set to empty string**: Treated as null (not included in `trustedKeys`)
4. **Key ID collision**: Extremely unlikely (2^64 hash space), not handled in Phase 2
5. **Requesting key by unknown ID**: Verification attempts with all trusted keys sequentially
6. **Very long PEM content**: Accepted if valid format and correct key size
7. **PEM with extra whitespace**: Accepted (whitespace normalized during parsing)
8. **PEM with comments**: Rejected as invalid format (standard PEM has no comments)
9. **PKCS#1 format vs PKCS#8**: Only PKCS#8 format accepted (standard "BEGIN PUBLIC KEY")
10. **Private key in PEM**: Rejected by `isValidKey()` (must be public key only)

**Error Handling**:
- Invalid primary key: Compile-time error (const validation)
- Invalid secondary key: Compile-time error (const validation)
- `isValidKey()` returns false for invalid keys, does not throw
- `getKeyId()` throws `FormatException` if key PEM is invalid

---

### D4.1: Compatibility Checker Service

**Type**: Dart Service Class
**File**: `src/shell/lib/modules/compatibility_checker.dart`
**Purpose**: Validate module compatibility with shell version

**Interface**:
```dart
class CompatibilityChecker {
  // Check if module version is compatible with current shell version
  Future<CompatibilityResult> checkCompatibility({
    required String moduleId,
    required String moduleVersion,
    required String requiredShellVersion,
  });

  // Get current shell version
  String getCurrentShellVersion();

  // Parse and validate semantic version range
  VersionRange parseVersionRange(String rangeString);
}

class CompatibilityResult {
  final bool isCompatible;
  final String shellVersion;
  final String requiredShellVersion;
  final String? incompatibilityReason;
  final List<String> warnings;

  CompatibilityResult({
    required this.isCompatible,
    required this.shellVersion,
    required this.requiredShellVersion,
    this.incompatibilityReason,
    this.warnings = const [],
  });
}

class VersionRange {
  final String min;  // Minimum version (inclusive)
  final String max;  // Maximum version (exclusive)
  final bool includeMax;  // If true, max is inclusive

  VersionRange({
    required this.min,
    required this.max,
    this.includeMax = false,
  });

  bool allows(String version);
}
```

**Data Structures**:
- Shell version: Hardcoded in `src/shell/pubspec.yaml` as `version: 1.0.0+1` (major.minor.patch+build)
- Semantic version format: `MAJOR.MINOR.PATCH` (e.g., "1.2.3")
- Version range formats:
  - Caret range: `^1.2.3` → `>=1.2.3 <2.0.0` (compatible with minor/patch updates)
  - Tilde range: `~1.2.3` → `>=1.2.3 <1.3.0` (compatible with patch updates only)
  - Exact range: `1.2.3` → `==1.2.3` (exact version match)
  - Greater than: `>=1.2.3` → minimum version (no maximum)
  - Range: `>=1.2.0 <2.0.0` → explicit range
- Comparison: Uses `semantic_version` package for parsing and comparison

**Constraints**:
- Shell version must be valid semantic version (parsing fails if malformed)
- Module requiredShellVersion must be valid range (parsing fails if malformed)
- Pre-release versions (e.g., "1.0.0-alpha") not supported in Phase 2 (treated as invalid)
- Build metadata (e.g., "1.0.0+123") ignored in version comparison
- Major version 0 treated specially: `^0.1.2` → `>=0.1.2 <0.2.0` (breaking changes in minor versions)
- Warnings generated for:
  - Shell version is much newer than module was tested with (>1 major version ahead)
  - Module requires shell version not yet released (future version)

**Edge Cases**:
1. **Invalid shell version in pubspec**: `checkCompatibility()` throws `StateError("Invalid shell version")`
2. **Invalid requiredShellVersion syntax**: Returns `CompatibilityResult(isCompatible: false, reason: "Invalid version range syntax")`
3. **Module requires future shell version**: Returns `isCompatible: false` with reason "Requires shell version {required}, current version is {current}"
4. **Module requires older major version**: Returns `isCompatible: false` with reason "Module requires shell {major}.x, current version is {current}"
5. **Exact version match**: `requiredShellVersion: "1.2.3"` only compatible with shell 1.2.3 exactly
6. **Unbounded range**: `>=1.0.0` compatible with any version >=1.0.0
7. **Overlapping ranges**: `>=1.0.0 <3.0.0` compatible with shell 1.x and 2.x
8. **Pre-release version**: Treated as invalid, returns `isCompatible: false`
9. **Shell version with build metadata**: Build metadata stripped before comparison (e.g., `1.0.0+5` → `1.0.0`)
10. **Very large version numbers**: Supported (e.g., `127.543.9999`)

**Error Handling**:
- Invalid shell version: Throw `StateError` (should never happen in production)
- Invalid module version range: Return `CompatibilityResult(isCompatible: false)` with error in `incompatibilityReason`
- Version parsing errors: Return `CompatibilityResult(isCompatible: false)` with parse error details
- No exceptions thrown from `checkCompatibility()` (all errors in result object)

---

### D4.2: Version Resolver Service

**Type**: Dart Service Class
**File**: `src/shell/lib/modules/version_resolver.dart`
**Purpose**: Select best compatible version from available options

**Interface**:
```dart
class VersionResolver {
  // Select best compatible version from list of available versions
  Future<VersionResolutionResult> resolveBestVersion({
    required String moduleId,
    required List<String> availableVersions,
    required String shellVersion,
  });

  // Compare two semantic versions (-1 if v1 < v2, 0 if equal, 1 if v1 > v2)
  int compareVersions(String version1, String version2);

  // Check if upgrade from oldVersion to newVersion is safe
  bool isSafeUpgrade(String oldVersion, String newVersion);
}

class VersionResolutionResult {
  final String? selectedVersion;
  final String? reason;
  final List<String> compatibleVersions;
  final List<String> warnings;

  VersionResolutionResult({
    this.selectedVersion,
    this.reason,
    this.compatibleVersions = const [],
    this.warnings = const [],
  });
}
```

**Data Structures**:
- Version comparison: Uses `semantic_version` package `Version.compareTo()`
- Safe upgrade definition: Major version unchanged (e.g., 1.2.3 → 1.5.0 is safe, 1.2.3 → 2.0.0 is not)
- Version sorting: Descending order (newest first)
- Selection algorithm: Choose highest compatible version that is safe upgrade from current

**Constraints**:
- `resolveBestVersion()` only considers versions compatible with `shellVersion`
- If multiple compatible versions, highest version selected
- Major version upgrades generate warning but may still be selected if no other option
- Empty `availableVersions` list returns `selectedVersion: null` with reason "No versions available"
- Invalid version strings in `availableVersions` skipped with warning logged
- `isSafeUpgrade()` returns false for downgrades (e.g., 2.0.0 → 1.9.0)

**Edge Cases**:
1. **No compatible versions**: Returns `selectedVersion: null` with reason "No compatible versions found"
2. **All versions incompatible**: Returns `selectedVersion: null` with `compatibleVersions: []`
3. **Only major version upgrade available**: Returns that version with warning "Major version upgrade detected"
4. **Current version is latest**: Returns current version with reason "Already on latest compatible version"
5. **Multiple versions with same compatibility**: Highest version selected
6. **Invalid version in availableVersions list**: Skipped, warning added to result
7. **Empty availableVersions list**: Returns `selectedVersion: null` with reason "No versions available"
8. **Downgrade scenario**: `isSafeUpgrade()` returns false, version not selected
9. **Pre-release versions in list**: Skipped (not supported in Phase 2)
10. **Very large number of available versions**: All evaluated (no performance limit in Phase 2)

**Error Handling**:
- Invalid version strings: Logged as warning, skipped from consideration
- Invalid shell version: Throws `ArgumentError("Invalid shell version")`
- Null or empty moduleId: Throws `ArgumentError("moduleId required")`
- No errors returned in `VersionResolutionResult` (all outcomes handled via reason and warnings)

---

### D5.1: Module Cache Manager

**Type**: Dart Service Class (singleton)
**File**: `src/shell/lib/modules/module_cache.dart`
**Purpose**: Manage module cache directory, size limits, and garbage collection

**Interface**:
```dart
class ModuleCache {
  static final ModuleCache instance = ModuleCache._internal();
  factory ModuleCache() => instance;

  // Get path to cached module file, returns null if not cached
  Future<String?> getCachedModulePath(String moduleId, String version);

  // Add module to cache from temporary file (atomic move operation)
  Future<CacheAddResult> addToCache({
    required String moduleId,
    required String version,
    required String tempFilePath,
    required ModuleManifest manifest,
  });

  // Remove specific version from cache
  Future<void> removeFromCache(String moduleId, String version);

  // List all cached versions for module
  Future<List<String>> listCachedVersions(String moduleId);

  // Get total cache size in bytes
  Future<int> getCacheSize();

  // Run garbage collection (remove old versions, enforce size limit)
  Future<GarbageCollectionResult> runGarbageCollection();

  // Get cache directory path
  Future<String> getCacheDirectory();
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
  final List<String> removedVersions;  // moduleId:version strings

  GarbageCollectionResult({
    required this.filesRemoved,
    required this.bytesFreed,
    required this.duration,
    this.removedVersions = const [],
  });
}
```

**Data Structures**:
- Cache directory structure:
  ```
  {app_support}/module_cache/
    {moduleId}/
      {version}/
        module.js
        module.manifest.json
        module.signature
        cache_metadata.json
  ```
- Cache metadata format: `{ "moduleId": "...", "version": "...", "cachedAt": "ISO-8601", "lastAccessedAt": "ISO-8601", "sizeBytes": 12345 }`
- Maximum cache size: 104857600 bytes (100 MB)
- Versions kept per module: Maximum 3 most recent versions
- Garbage collection trigger: Automatic when cache size exceeds 90 MB, manual via `runGarbageCollection()`

**Constraints**:
- Cache directory located at: `{getApplicationSupportDirectory()}/module_cache`
- Atomic add operation: Copy temp file to `.tmp` in cache, verify, rename to final name
- Cache metadata updated on every access (updates `lastAccessedAt` timestamp)
- Garbage collection removes: Oldest versions beyond 3-version limit, oldest accessed files when over size limit
- Last-known-good versions never removed by garbage collection (marked in metadata)
- Concurrent cache operations serialized with mutex lock
- Cache survives app restart (persisted to disk)

**Edge Cases**:
1. **Cache directory doesn't exist**: Created automatically on first `addToCache()` call
2. **Disk full during addToCache**: Returns `CacheAddResult(success: false, error: "Disk full")`
3. **Module already cached**: Existing version replaced, old file deleted
4. **Cache size exceeds limit**: Next `addToCache()` triggers automatic garbage collection before adding
5. **Garbage collection removes last-known-good**: Last-known-good versions protected, not removed
6. **Corrupted cache metadata file**: File deleted, module re-added to cache on next install
7. **Missing module.js but metadata exists**: Metadata removed, returns null from `getCachedModulePath()`
8. **Concurrent addToCache for same module**: Second call waits for first to complete via mutex
9. **Orphaned files in cache (no metadata)**: Removed during garbage collection
10. **Very large module exceeds cache size limit**: Garbage collection frees space, then module added (may exceed limit temporarily)

**Error Handling**:
- File I/O errors during add: Return `CacheAddResult(success: false, error: "{details}")`
- File I/O errors during remove: Log warning, continue (best effort)
- Directory creation errors: Throw `StateError("Failed to create cache directory")`
- Metadata parsing errors: Delete corrupt metadata file, re-create on next access
- Garbage collection errors: Log errors, return partial result with what was successfully removed

---

### D5.2: Fallback Manager Service

**Type**: Dart Service Class (singleton)
**File**: `src/shell/lib/modules/fallback_manager.dart`
**Purpose**: Track module load failures and automatic rollback to last-known-good

**Interface**:
```dart
class FallbackManager {
  static final FallbackManager instance = FallbackManager._internal();
  factory FallbackManager() => instance;

  // Record module load failure
  Future<void> recordLoadFailure({
    required String moduleId,
    required String version,
    required String error,
  });

  // Get last-known-good version for module, returns null if no known-good version
  Future<String?> getLastKnownGoodVersion(String moduleId);

  // Mark version as last-known-good after successful load
  Future<void> markAsLastKnownGood({
    required String moduleId,
    required String version,
  });

  // Attempt automatic rollback, returns version rolled back to
  Future<FallbackResult> attemptFallback(String moduleId);

  // Get failure count for specific version
  Future<int> getFailureCount(String moduleId, String version);

  // Reset failure tracking for module (e.g., after successful load)
  Future<void> resetFailures(String moduleId);

  // Check if module should be blocked from loading due to repeated failures
  Future<bool> isBlocked(String moduleId, String version);
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
```

**Data Structures**:
- Failure tracking storage: SQLite database table `module_failures(module_id TEXT, version TEXT, failure_count INTEGER, last_failure_at INTEGER, error_message TEXT, PRIMARY KEY(module_id, version))`
- Last-known-good storage: SQLite database table `last_known_good(module_id TEXT PRIMARY KEY, version TEXT, marked_at INTEGER)`
- Failure threshold: 3 consecutive failures triggers automatic rollback
- Block threshold: 5 total failures (across rollback attempts) triggers permanent block until manual intervention
- Failure reset: Successful load resets failure count to 0

**Constraints**:
- Failure count incremented each time `recordLoadFailure()` called
- Last-known-good version only set via explicit `markAsLastKnownGood()` call after successful load
- Fallback attempts: Maximum 2 automatic rollbacks, then requires user intervention
- Blocked versions cannot be loaded until `resetFailures()` called manually
- User notification required when: Fallback occurs, block threshold reached, no last-known-good available
- Failure tracking persists across app restarts

**Edge Cases**:
1. **No last-known-good version exists**: `attemptFallback()` returns `success: false, error: "No known-good version available"`
2. **Last-known-good version also fails**: Increment failure count, try next older cached version if available
3. **All cached versions fail**: Return `FallbackResult` with `userNotificationRequired: true` and error "No working version available"
4. **Module fails 3 times**: Automatic rollback triggered on 3rd failure
5. **Module fails 5 times total**: Blocked, returns `isBlocked: true`
6. **Rollback to same version as failed**: Not allowed, rollback only to older versions
7. **Concurrent load failures**: Failure count incremented atomically (database transaction)
8. **First load of new module**: No last-known-good, first successful load sets it
9. **Manual version downgrade**: Does not affect failure count or last-known-good
10. **Failure during fallback attempt**: Counted as additional failure, may trigger block

**Error Handling**:
- Database errors on record: Log error, continue (failure not recorded)
- Database errors on mark: Throw `StateError("Failed to mark last-known-good")`
- Missing last-known-good record: Return null from `getLastKnownGoodVersion()`
- Fallback to non-existent version: Return `FallbackResult(success: false, error: "Fallback version not in cache")`

---

### D6.1: Dynamic Module Loader (JavaScript)

**Type**: JavaScript Module
**File**: `src/runtime-host/module-loader.js`
**Purpose**: Load modules dynamically from cache with version detection and failure handling

**Interface**:
```javascript
export class ModuleLoader {
  // Load module from cache path
  async loadModule(config: ModuleLoadConfig): Promise<ModuleLoadResult>;

  // Unload currently loaded module
  async unloadModule(): Promise<void>;

  // Get currently loaded module info
  getCurrentModule(): ModuleInfo | null;

  // Detect module version from module code
  detectModuleVersion(moduleCode: string): string | null;

  // Event emitter for load events
  on(event: string, handler: Function): void;
  off(event: string, handler: Function): void;
}

interface ModuleLoadConfig {
  moduleId: string;
  version: string;
  cachePath: string;      // Absolute file path to module.js in cache
  context: ModuleContext; // Position context and session from bridge
  retryOnFailure: boolean; // Default: false
}

interface ModuleLoadResult {
  success: boolean;
  moduleInfo?: ModuleInfo;
  error?: string;
  loadDuration?: number; // milliseconds
}

interface ModuleInfo {
  moduleId: string;
  version: string;
  loadedAt: Date;
  hasInitFunction: boolean;
  hasCleanupFunction: boolean;
  hasRenderFunction: boolean;
}

interface ModuleContext {
  session: ScopedSession;
  position: PositionContext;
  runtimeAPI: RuntimeAPI;
}
```

**Data Structures**:
- Module code execution: Loaded via dynamic `import()` or `<script>` tag injection with `type="module"`
- Version detection: Parse module code for `export const MODULE_VERSION = "1.2.3"` declaration
- Module isolation: Each module loaded in separate scope (using ES modules)
- Load retry: If `retryOnFailure: true`, retry once after 1 second delay
- Load events: `loading`, `loaded`, `load-failed`, `unloading`, `unloaded`

**Constraints**:
- Only one module can be loaded at a time (unload previous before loading new)
- Module must export `init`, `cleanup`, and `render` functions (checked after load)
- Module code loaded from file path (not URL) in Phase 2
- Load timeout: 10 seconds, after which load fails with timeout error
- Version detection optional: If no `MODULE_VERSION` export found, version from config used
- Module code must be valid ES module (will fail to load if syntax errors)

**Edge Cases**:
1. **Module file not found at cachePath**: Returns `{ success: false, error: "Module file not found" }`
2. **Module has syntax errors**: Returns `{ success: false, error: "Module parse error: {details}" }`
3. **Module missing required exports**: Returns `{ success: false, error: "Module missing required function: {functionName}" }`
4. **Module init() throws error**: Returns `{ success: false, error: "Module initialization failed: {details}" }`
5. **Load timeout**: Returns `{ success: false, error: "Module load timeout after 10 seconds" }`
6. **Module version mismatch**: Log warning, proceed with load (version from config takes precedence)
7. **Concurrent loadModule calls**: Second call waits for first to complete, then proceeds
8. **Unload while loading**: Load cancelled, module not initialized
9. **Module cleanup() throws error**: Log error, continue with unload (best effort)
10. **Very large module file (>10 MB)**: Load proceeds (no size limit in loader, cache enforces limit)

**Error Handling**:
- File load errors: Return `ModuleLoadResult` with `success: false` and error description
- Parse errors: Return `ModuleLoadResult` with `success: false` and syntax error details
- Init errors: Return `ModuleLoadResult` with `success: false` and init error message
- Timeout errors: Return `ModuleLoadResult` with `success: false` and timeout message
- All errors communicated via result object, no exceptions thrown from `loadModule()`
- Load failures trigger `load-failed` event with error details

---

### D6.2: Update Notification UI (JavaScript)

**Type**: JavaScript Module
**File**: `src/runtime-host/update-notification.js`
**Purpose**: Display update availability and progress to users

**Interface**:
```javascript
export class UpdateNotification {
  // Show notification that update is available
  showUpdateAvailable(config: UpdateAvailableConfig): void;

  // Show update progress during installation
  showUpdateProgress(progress: UpdateProgressData): void;

  // Show update completion message
  showUpdateComplete(version: string): void;

  // Show update error message
  showUpdateError(error: string): void;

  // Dismiss notification
  dismiss(): void;

  // Check if notification is currently visible
  isVisible(): boolean;

  // Event emitter for user actions
  on(event: string, handler: Function): void;
}

interface UpdateAvailableConfig {
  moduleId: string;
  currentVersion: string;
  newVersion: string;
  requiresReload: boolean;  // If module currently loaded
  changelog?: string;
}

interface UpdateProgressData {
  phase: 'downloading' | 'verifying' | 'installing';
  percentComplete: number; // 0-100
  currentOperation?: string;
}
```

**Data Structures**:
- Notification UI: Toast/snackbar style notification at bottom of screen
- Notification timeout: Auto-dismiss after 10 seconds for non-critical notifications
- Notification persistence: Update progress notifications persist until complete/error
- User actions: "Update Now", "Dismiss", "View Details" buttons
- Notification events: `update-accepted`, `update-dismissed`, `details-requested`

**Constraints**:
- Only one notification visible at a time (new notification replaces old)
- Update progress notifications cannot be dismissed (only error/complete can)
- Notification z-index: 9999 (appears above all module content)
- Notification width: Maximum 400px, responsive on mobile
- Update available notification persists until user action or 60 seconds
- Progress updates throttled to maximum 2 updates per second (avoid UI thrashing)

**Edge Cases**:
1. **Multiple update notifications**: Last notification replaces previous
2. **Notification during module unmount**: Notification persists (attached to runtime host, not module)
3. **User dismisses while downloading**: Download continues in background
4. **Update complete while notification dismissed**: New notification shown for completion
5. **Error during update**: Progress notification replaced with error notification
6. **Very long changelog**: Truncated to 200 characters with "Read more" link
7. **Update available but module not loaded**: Notification shown in runtime host UI
8. **Rapid progress updates**: Throttled to max 2 updates/second
9. **Notification shown on small screen**: Responsive, collapses to smaller size
10. **Multiple modules updating**: Separate notification per module (stacked vertically)

**Error Handling**:
- DOM manipulation errors: Log error, notification may not appear but does not crash
- Missing container element: Create container dynamically
- CSS not loaded: Use inline styles as fallback
- Event handler errors: Caught and logged, do not propagate

---

### D7.1: Module Bridge Extension

**Type**: Dart Class
**File**: `src/shell/lib/bridge/module_bridge_extension.dart`
**Purpose**: Extend Flutter-WebView bridge with module management methods

**Interface**:
```dart
class ModuleBridgeExtension {
  // Check for updates for specific module
  Future<Map<String, dynamic>> checkForUpdates(String moduleId);

  // Get list of all available modules from registry
  Future<Map<String, dynamic>> getAvailableModules();

  // Get current installed version for module
  Future<Map<String, dynamic>> getModuleVersion(String moduleId);

  // Install module update
  Future<Map<String, dynamic>> installModuleUpdate(String moduleId, String version);

  // Cancel in-progress update
  Future<Map<String, dynamic>> cancelModuleUpdate(String moduleId);

  // Get update progress for module
  Future<Map<String, dynamic>> getUpdateProgress(String moduleId);

  // Register these methods with ShellBridge
  void registerWithBridge(ShellBridge bridge);
}

// Return type structures (as JSON maps):

// checkForUpdates result:
{
  "success": bool,
  "updateAvailable": bool,
  "currentVersion": string?,
  "latestVersion": string?,
  "error": string?
}

// getAvailableModules result:
{
  "success": bool,
  "modules": [
    {
      "moduleId": string,
      "version": string,
      "isInstalled": bool,
      "requiredShellVersion": string
    }
  ],
  "error": string?
}

// getModuleVersion result:
{
  "success": bool,
  "moduleId": string,
  "version": string?,
  "error": string?
}

// installModuleUpdate result:
{
  "success": bool,
  "installedVersion": string?,
  "error": string?
}

// cancelModuleUpdate result:
{
  "success": bool,
  "cancelled": bool,
  "error": string?
}

// getUpdateProgress result:
{
  "success": bool,
  "status": string,  // "idle", "checking", "downloading", "verifying", "installing", "complete", "failed"
  "percentComplete": number,  // 0-100
  "currentOperation": string?,
  "error": string?
}
```

**Data Structures**:
- Bridge method registration: Methods added to ShellBridge method channel with names `module.checkForUpdates`, `module.getAvailableModules`, etc.
- JSON serialization: All return values serialized to JSON-compatible maps
- Error responses: Always include `success: false` and `error: "description"` fields
- Success responses: Always include `success: true` and relevant data fields

**Constraints**:
- Implementation must import dart:async library when using TimeoutException or other async error types. The bridge extension uses TimeoutException for timeout error handling in bridge method calls and must include: import 'dart:async';
- All bridge methods must validate session before executing (reuse session validation from Phase 1)
- Methods are asynchronous (return `Future<Map<String, dynamic>>`)
- Method names prefixed with `module.` to namespace (e.g., `module.checkForUpdates`)
- Maximum method call frequency: 10 calls per second (throttled)
- Methods timeout after 60 seconds if not completed
- All methods return JSON-serializable data only (no Dart objects)

**Edge Cases**:
1. **Module not found**: Return `{ success: false, error: "Module not found" }`
2. **Registry not loaded**: Return `{ success: false, error: "Module registry not loaded" }`
3. **Invalid session**: Return `{ success: false, error: "Invalid session" }`
4. **Network error during check**: Return `{ success: false, error: "Network error: {details}" }`
5. **Install while module loaded**: Return `{ success: true, requiresReload: true }`
6. **Cancel when not updating**: Return `{ success: true, cancelled: false }` (no-op)
7. **Concurrent install calls**: Second call returns `{ success: false, error: "Update already in progress" }`
8. **Method called before registerWithBridge**: Throws `StateError("Bridge extension not registered")`
9. **Very large module list**: Return first 100 modules, include `hasMore: true` flag
10. **Bridge method timeout**: Return `{ success: false, error: "Operation timeout" }`

**Error Handling**:
- All errors caught and returned as `{ success: false, error: "..." }` maps
- No exceptions thrown from bridge methods (all errors in return value)
- Timeout errors: Return timeout message after 60 seconds
- Session validation errors: Return session error before attempting operation
- Network errors: Include network error details in error message
- All errors logged to console with timestamp

---

### D8.1-D8.13: Test Deliverables

Each test file must include executable Dart test cases using Flutter test framework. Tests must not be stubs or pseudo-code.

**Common Test Constraints**:
- All tests use `flutter test` command
- Tests are isolated (no shared state between test cases)
- Tests use proper setup/teardown for cleanup
- Mock services used where appropriate (network, file system for unit tests)
- Integration tests may use test doubles for external dependencies
- All tests have clear assertion messages
- Tests cover both success and failure paths

**Test File Syntax Requirements** (D8.4 - Fallback Tests):
- Test files must have valid Dart syntax. The test framework requires:
  - Balanced braces in group() and test() blocks
  - setUp() and tearDown() callbacks properly scoped within group()
  - All variables declared in setUp() must be accessible in test() blocks
- Test file structure:
  ```dart
  void main() {
    group('ComponentName', () {
      late VariableType variable;

      setUp(() {
        variable = VariableType();
      });

      tearDown(() {
        // cleanup
      });

      test('test name', () {
        // variable is accessible here
      });
    });
  }
  ```

**Test Setup Requirements for Platform Channels** (D8.9 - Last-Known-Good Tests, D8.11 - Multi-Version Cache Tests):
- Tests that use platform channels must initialize Flutter bindings before test execution.
- Required setup for tests using:
  - path_provider (file system access)
  - sqflite (database access)
  - shared_preferences (persistent storage)
  - Any other platform plugin
- Add as first line in main() function:
  ```dart
  TestWidgetsFlutterBinding.ensureInitialized();
  ```
- This initializes the Flutter framework's platform channel communication layer, which is required for native platform functionality in tests.
- Without this initialization, path_provider calls will throw MissingPluginException and tests will either fail or return default values instead of real file system operations.

**Integration Test Execution Requirements** (D8.13 - Cache Load Performance Tests):
- This is an INTEGRATION TEST that requires running on a physical device or emulator.
- File location: Move from test/integration/ to integration_test/ directory
- Test execution:
  - Cannot run with 'flutter test' (unit test mode)
  - Must run with device/emulator active
  - Execute with: flutter test integration_test/cached_module_load_test.dart
- Why integration test:
  - Tests real file system I/O performance
  - Measures actual cache load time (<200ms requirement)
  - Requires platform plugins fully registered
- The integration_test/ directory is Flutter's designated location for tests that need device/emulator execution. Tests in test/ directory run in VM mode without full plugin registration.

**Test Execution**:
- Unit tests: `flutter test test/modules/{test_file}.dart`
- Integration tests: `flutter test integration_test/{test_file}.dart`
- All tests: `flutter test`

Specific test file specifications provided in Acceptance Criteria section below.

---

### D9.1: Module Manifest v1.1.0

**Type**: JSON file
**File**: `src/modules/sample-warehouse/module.manifest.json`
**Purpose**: Metadata for sample module version 1.1.0

**Data Structure**:
```json
{
  "moduleId": "warehouse-clerk",
  "version": "1.1.0",
  "requiredShellVersion": "^1.0.0",
  "signature": "{344-character-base64-encoded-RSA-signature}",
  "downloadUrl": "https://mock-cdn.example.com/modules/warehouse-clerk/1.1.0/module.js",
  "checksum": "{64-character-hex-sha256}",
  "downloadSizeBytes": 245760,
  "publishedAt": "2026-03-14T10:00:00Z",
  "metadata": {
    "changelog": "Added inventory search feature, improved performance",
    "minOSVersion": "Android 8.0 / iOS 13.0"
  }
}
```

**Constraints**:
- Must pass `ModuleManifest.validate()` without errors
- Signature must be valid for module.js file (generated using RSA-2048 private key)
- Checksum must match SHA-256 hash of module.js file
- downloadSizeBytes must match actual file size
- requiredShellVersion must be compatible with shell v1.0.0

---

### D9.2: Sample Module v1.1.0

**Type**: TypeScript/React module
**File**: `src/modules/sample-warehouse-v1.1.0/index.tsx`
**Purpose**: Updated version of warehouse module demonstrating new features

**Interface**:
Must export standard module contract:
```typescript
export const MODULE_VERSION = "1.1.0";

export async function init(params: ModuleInitParams): Promise<void>;
export async function cleanup(): Promise<void>;
export function render(container: HTMLElement): void;
```

**Constraints**:
- Must include version indicator in UI showing "v1.1.0"
- Must be compatible with runtime-contract.ts from Phase 1
- Must demonstrate at least one new feature vs v1.0.0 (e.g., inventory search UI)
- Must build with Vite/TypeScript successfully
- Bundle size must be ≤ 50 MB
- Must load and render without errors in runtime host

---

### D9.3: Module Package.json v1.1.0

**Type**: JSON file
**File**: `src/modules/sample-warehouse-v1.1.0/package.json`
**Purpose**: Build configuration and dependencies for module v1.1.0

**Data Structure**:
```json
{
  "name": "warehouse-clerk-module",
  "version": "1.1.0",
  "type": "module",
  "scripts": {
    "build": "vite build",
    "dev": "vite"
  },
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0"
  },
  "devDependencies": {
    "@types/react": "^18.2.0",
    "@types/react-dom": "^18.2.0",
    "typescript": "^5.3.0",
    "vite": "^5.0.0"
  }
}
```

---

## General Implementation Constraints

The following constraints apply to all Dart and Flutter code in this phase:

### Dart Import Requirements

- Import dart:async when using: Completer, Future, Stream, TimeoutException, Timer
- Import dart:io when using: File, Directory, HttpClient, Socket
- Import dart:convert when using: json.encode, json.decode, JsonEncoder
- Import relative files when using custom classes from other files
- Run 'flutter analyze' before marking code complete to catch missing imports

### Flutter Test Requirements

- Unit tests (test/ directory): Run in Dart VM, no device needed
- Integration tests (integration_test/ directory): Require device/emulator
- Tests using platform channels must call TestWidgetsFlutterBinding.ensureInitialized()
- Platform channels include: path_provider, sqflite, shared_preferences, url_launcher
- Run 'flutter test' to verify all tests pass before marking complete

### Code Completion Checklist

Before marking implementation complete, verify:
- □ flutter analyze shows no errors
- □ flutter test passes all unit tests
- □ All imports present for used types
- □ Test files in correct directory (test/ vs integration_test/)
- □ Platform-dependent tests initialize bindings

---

## Phase Boundaries

### Receives From Previous Phase (Phase 1)

**From Phase 1 Built.md — Exact Interfaces**:

1. **SessionBroker** (Dart Service Class)
   - Location: `src/shell/lib/session/session_broker.dart`
   - Methods:
     - `Future<BootstrapCode> generateBootstrapCode(Position position)` → Creates one-time bootstrap with 60-second expiry
     - `Future<ScopedSession> redeemBootstrap(String code, Position position)` → Converts bootstrap to 8-hour scoped session
     - `Future<SessionValidation> validateSession(String sessionId)` → Checks if session is active and valid
     - `Future<void> revokeSession(String sessionId)` → Invalidates session immediately
     - `int get activeSessionCount` → Returns count of active sessions
   - Data Structures:
     - `BootstrapCode`: { code: String, expiresAt: DateTime, positionId: String }
     - `ScopedSession`: { sessionId: String, positionId: String, orgId: String, roleContext: Map<String, dynamic>, createdAt: DateTime, expiresAt: DateTime }
     - `SessionValidation`: { isValid: bool, sessionId: String?, error: String? }

2. **RuntimeHostAPI** (JavaScript Module)
   - Location: `src/runtime-host/runtime-host.js`
   - Methods:
     - `async initialize()` → Bootstraps runtime with bridge redemption
     - `async mountModule(moduleConfig)` → Loads and mounts position module (currently static, Phase 2 makes dynamic)
     - `async unmountModule()` → Cleans up current module
     - `getModuleStatus()` → Returns `{ mounted: bool, moduleId: string?, error: string? }`
     - `on(eventName, handler)` → Subscribe to runtime events (mount, unmount, error)

3. **ShellBridge** (Dart Bridge Class)
   - Location: `src/shell/lib/bridge/shell_bridge.dart`
   - Methods:
     - `Future<Map<String, dynamic>> getBootstrapCode()` → Returns `{ code: string, expiresAt: ISO-8601 }`
     - `Future<Map<String, dynamic>> redeemBootstrap(String code)` → Returns `{ sessionId: string, positionId: string, orgId: string, roleContext: {} }`
     - `Future<Map<String, dynamic>> validateSession(String sessionId)` → Returns `{ valid: bool, error: string? }`
     - `Future<void> revokeSession(String sessionId)` → No return value
     - `Future<Map<String, dynamic>> getPositionContext()` → Returns `{ positionId: string, positionName: string, orgId: string, roleContext: {} }`
     - `Future<void> unmountModule(String? sessionId)` → Cleans up module and optionally revokes session
   - All methods registered on method channel, callable from JavaScript via bridge

4. **Cache Directory Access**
   - Via `path_provider` package: `getApplicationSupportDirectory()` for persistent cache
   - Via `getTemporaryDirectory()` for temporary downloads
   - Directories created in Phase 1 setup

### Provides To Next Phase (Phase 3+)

1. **ModuleRegistry** (Dart Service Class)
   - Location: `src/shell/lib/modules/module_registry.dart`
   - Methods:
     - `Future<String?> getInstalledVersion(String moduleId)` → Returns version string or null if not installed
     - `Future<List<ModuleMetadata>> getCachedModules()` → Returns list of all cached module metadata
     - `Future<bool> isModuleCached(String moduleId, String version)` → Returns true if specific version is in cache
   - Purpose: Phase 3 offline support can check cached modules before attempting network operations

2. **ModuleCache** (Dart Service Class)
   - Location: `src/shell/lib/modules/module_cache.dart`
   - Methods:
     - `Future<String?> getCachedModulePath(String moduleId, String version)` → Returns absolute file path to cached module.js or null
     - `Future<List<String>> listCachedVersions(String moduleId)` → Returns list of version strings cached for module
     - `Future<int> getCacheSize()` → Returns total cache size in bytes
   - Purpose: Phase 3 can load modules directly from cache without network access

3. **UpdateStateTracker** (Part of ModuleUpdater)
   - Location: `src/shell/lib/modules/module_updater.dart`
   - Methods:
     - `UpdateState getUpdateState(String moduleId)` → Returns current update state (idle, downloading, etc.)
     - `Future<Map<String, UpdateCheckResult>> checkAllModulesForUpdates()` → Returns map of moduleId to update check results
     - `Future<void> markUpdateFailed(String moduleId, String reason)` → Records failed update attempt
   - Purpose: Phase 3 can defer updates when offline, track pending updates

4. **Verified Module Storage** (File System + Database)
   - Cache directory: `{app_support}/module_cache/{moduleId}/{version}/`
   - Database tables:
     - `installed_modules(module_id TEXT, version TEXT, installed_at INTEGER, PRIMARY KEY(module_id, version))`
     - `last_known_good(module_id TEXT PRIMARY KEY, version TEXT, marked_at INTEGER)`
     - `module_failures(module_id TEXT, version TEXT, failure_count INTEGER, last_failure_at INTEGER, error_message TEXT, PRIMARY KEY(module_id, version))`
   - Purpose: Phase 3 has access to verified, signature-checked modules for offline loading

---

## Acceptance Criteria

### AC-1: Module Manifest Loads and Parses Correctly

**Criterion**: Module manifest JSON is parsed correctly with all required fields validated, and invalid manifests are rejected with clear error messages.

**test_command**:
```bash
cd C:\Users\bijay\OneDrive\Desktop\auto_agent3\pocs\output\foundry-position-shell-poc && flutter test tests\modules\module_manifest_test.dart
```

**pass_condition**:
- Exit code 0 (all tests pass)
- Valid manifest with all required fields parses successfully: `ModuleManifest.fromJson()` returns object with all fields populated
- Missing required field (e.g., moduleId): `fromJson()` throws `FormatException` with message containing "Missing required field: moduleId"
- Invalid moduleId format (e.g., "Invalid-ID!"): `validate()` returns `ManifestValidationResult(isValid: false, errors: ["moduleId must match pattern ^[a-z][a-z0-9-]{2,63}$"])`
- Invalid version format (e.g., "v1.2"): `validate()` returns `isValid: false` with error "version must be valid semantic version"
- Invalid checksum length: `validate()` returns `isValid: false` with error "checksum must be 64 hexadecimal characters"
- Non-HTTPS downloadUrl: `validate()` returns `isValid: false` with error "downloadUrl must use HTTPS scheme"
- Test suite includes minimum 8 test cases covering: valid manifest, missing fields, invalid formats, edge cases

**Blocking**: Yes (required for all subsequent manifest operations)

---

### AC-2: Semantic Version Compatibility Check Works

**Criterion**: Semantic version compatibility checking correctly accepts compatible versions and rejects incompatible versions based on semver range notation.

**test_command**:
```bash
cd C:\Users\bijay\OneDrive\Desktop\auto_agent3\pocs\output\foundry-position-shell-poc && flutter test tests\modules\version_compatibility_test.dart
```

**pass_condition**:
- Exit code 0 (all tests pass)
- Shell v1.2.0 with module requiring `^1.0.0`: `CompatibilityChecker.checkCompatibility()` returns `CompatibilityResult(isCompatible: true)`
- Shell v1.0.0 with module requiring `^2.0.0`: Returns `isCompatible: false` with reason "Module requires shell 2.x, current version is 1.0.0"
- Shell v2.5.0 with module requiring `^1.0.0`: Returns `isCompatible: false` (major version mismatch)
- Shell v1.5.0 with module requiring `~1.2.0`: Returns `isCompatible: true` (within patch range)
- Shell v1.1.0 with module requiring `~1.2.0`: Returns `isCompatible: false` (outside patch range)
- Exact version match: Shell v1.2.3 with module requiring `1.2.3` returns `isCompatible: true`
- Invalid version range syntax: Returns `isCompatible: false` with reason "Invalid version range syntax"
- Test suite includes minimum 10 test cases covering: caret ranges, tilde ranges, exact versions, major version mismatches, invalid syntax

**Blocking**: Yes (required to prevent incompatible module installations)

---

### AC-3: Module Download Completes with Checksum Validation

**Criterion**: Module files are downloaded successfully to cache with SHA-256 checksum verification, and corrupted downloads are rejected.

**test_command**:
```bash
cd C:\Users\bijay\OneDrive\Desktop\auto_agent3\pocs\output\foundry-position-shell-poc && flutter test tests\modules\module_download_test.dart
```

**pass_condition**:
- Exit code 0 (all tests pass)
- Successful download: `ModuleDownloader.downloadModule()` returns `DownloadResult(success: true, checksumValid: true, tempFilePath: {non-null-path})`
- Downloaded file exists at returned tempFilePath
- Checksum mismatch: Returns `DownloadResult(success: false, checksumValid: false, error: "Checksum mismatch")`
- Network error: Returns `DownloadResult(success: false, error: "Network error: {details}")`
- Download timeout (mock 5+ minute delay): Returns `DownloadResult(success: false, error: "Download timeout")`
- Progress callback invoked: onProgress called at least 2 times during mock download with increasing bytesDownloaded
- Retry on failure: After network error, retry attempt made (logged), up to 3 total attempts
- Test suite includes minimum 8 test cases covering: successful download, checksum validation, network errors, timeouts, retries, progress tracking

**Blocking**: Yes (required for update installation)

---

### AC-4: Signature Verification Accepts Valid Signatures

**Criterion**: Module files with valid RSA-2048 signatures are accepted, and modules with invalid, missing, or tampered signatures are rejected.

**test_command**:
```bash
cd C:\Users\bijay\OneDrive\Desktop\auto_agent3\pocs\output\foundry-position-shell-poc && flutter test tests\modules\signature_verification_test.dart
```

**pass_condition**:
- Exit code 0 (all tests pass)
- Valid signature: `ModuleVerifier.verifyModule()` returns `VerificationResult(isValid: true)`
- Invalid signature: Returns `VerificationResult(isValid: false, error: "Signature verification failed")`
- Missing signature: Returns `isValid: false` with error containing "signature"
- Tampered file (modified after signing): Returns `isValid: false`
- Wrong signature (signature from different file): Returns `isValid: false`
- Invalid base64 signature: Returns `isValid: false` with error "Invalid base64 signature"
- Wrong key size (mock 1024-bit key): `loadPublicKey()` throws `FormatException("Key must be RSA-2048")`
- Test suite includes minimum 8 test cases covering: valid signatures, invalid signatures, tampered files, missing signatures, key validation

**Blocking**: Yes (critical security requirement, must not allow unsigned modules)

---

### AC-5: Update Check Detects Available Updates

**Criterion**: Update checking queries the module registry, detects when newer compatible versions are available, and reports update information.

**test_command**:
```bash
cd C:\Users\bijay\OneDrive\Desktop\auto_agent3\pocs\output\foundry-position-shell-poc && flutter test tests\modules\update_check_test.dart
```

**pass_condition**:
- Exit code 0 (all tests pass)
- Update available: `ModuleUpdater.checkForUpdates(moduleId)` returns `UpdateCheckResult(updateAvailable: true, latestVersion: "1.2.0", currentVersion: "1.0.0")`
- No update available (current is latest): Returns `updateAvailable: false` with `latestVersion == currentVersion`
- Module not in registry: Returns `updateAvailable: false` with `error: "Module not found in registry"`
- Registry not loaded: Returns `updateAvailable: false` with `error: "Module registry not loaded"`
- Network error during check: Returns `updateAvailable: false` with `error: "Network error: {details}"`
- Only incompatible versions available: Returns `updateAvailable: false` (newer version exists but incompatible)
- Test suite includes minimum 6 test cases covering: updates available, no updates, module not found, registry errors, compatibility filtering

**Blocking**: Yes (required for update flow)

---

### AC-6: Module Update Installs Without Shell Reinstall

**Criterion**: Module version 1.0.0 can be updated to version 1.1.0 via download-verify-install process without restarting the Flutter application, and the new version loads successfully.

**Test Prerequisites**: All module update components must compile successfully. This requires:
- module_downloader.dart imports dart:async
- module_verifier.dart imports dart:async
- module_updater.dart imports module_manifest.dart

If compilation fails with 'Method not found' or 'isn't a type' errors, check for missing imports.

**test_command**:
```bash
cd C:\Users\bijay\OneDrive\Desktop\auto_agent3\pocs\output\foundry-position-shell-poc && flutter test integration_test\module_update_test.dart
```

**pass_condition**:
- Exit code 0 (all tests pass)
- Module v1.0.0 marked as installed initially
- `ModuleUpdater.installUpdate(moduleId: "warehouse-clerk", version: "1.1.0")` returns `InstallResult(success: true, installedVersion: "1.1.0")`
- Update state transitions through: downloading → verifying → installing → complete
- After installation, `ModuleRegistry.getInstalledVersion()` returns "1.1.0"
- After installation, `ModuleCache.getCachedModulePath("warehouse-clerk", "1.1.0")` returns non-null path
- Module v1.1.0 loads successfully via `ModuleLoader.loadModule()` without app restart
- Test demonstrates complete flow in single test execution (no manual steps)
- Integration test may use mock HTTP server for download simulation

**Blocking**: Yes (core requirement of Phase 2)

---

### AC-7: Failed Module Load Triggers Automatic Fallback

**Criterion**: When a module fails to load (e.g., syntax error, runtime error in init), the fallback manager automatically rolls back to the last-known-good version and notifies the user.

**test_command**:
```bash
cd C:\Users\bijay\OneDrive\Desktop\auto_agent3\pocs\output\foundry-position-shell-poc && flutter test tests\modules\fallback_test.dart
```

**pass_condition**:
- Exit code 0 (all tests pass)
- Module v1.0.0 marked as last-known-good
- Module v1.1.0 load fails (mock syntax error): `ModuleLoader.loadModule()` returns `ModuleLoadResult(success: false)`
- Failure recorded: `FallbackManager.getFailureCount()` returns 1
- After 3 failures: `FallbackManager.attemptFallback()` automatically called
- Fallback result: `FallbackResult(success: true, fallbackVersion: "1.0.0", userNotificationRequired: true)`
- Module v1.0.0 loaded after fallback
- User notification event emitted with fallback details
- Test suite includes minimum 6 test cases covering: single failure, multiple failures triggering fallback, successful fallback, no last-known-good scenario

**Blocking**: Yes (critical for user experience and reliability)

---

### AC-8: Last-Known-Good Version Persists After Successful Load

**Criterion**: When a module version loads successfully, it is marked as last-known-good and this state persists across application restarts.

**test_command**:
```bash
cd C:\Users\bijay\OneDrive\Desktop\auto_agent3\pocs\output\foundry-position-shell-poc && flutter test tests\modules\last_known_good_test.dart
```

**pass_condition**:
- Exit code 0 (all tests pass)
- Module v1.1.0 loads successfully
- `FallbackManager.markAsLastKnownGood(moduleId, "1.1.0")` called
- `FallbackManager.getLastKnownGoodVersion(moduleId)` immediately returns "1.1.0"
- Mock app restart (re-initialize FallbackManager with fresh database connection)
- After restart: `getLastKnownGoodVersion()` still returns "1.1.0" (persisted in database)
- New version v1.2.0 loads successfully and becomes new last-known-good
- `getLastKnownGoodVersion()` now returns "1.2.0" (updated)
- Test suite includes minimum 4 test cases covering: initial mark, persistence across restart, update to new version, no last-known-good initially

**Blocking**: Yes (required for fallback mechanism)

---

### AC-9: Incompatible Module Version Rejected Before Download

**Criterion**: Module versions that require a newer shell version than currently running are rejected during compatibility check before any download is attempted.

**test_command**:
```bash
cd C:\Users\bijay\OneDrive\Desktop\auto_agent3\pocs\output\foundry-position-shell-poc && flutter test tests\modules\compatibility_rejection_test.dart
```

**pass_condition**:
- Exit code 0 (all tests pass)
- Shell version 1.0.0 (mock current version)
- Module manifest requires `^2.0.0`
- `CompatibilityChecker.checkCompatibility()` returns `CompatibilityResult(isCompatible: false, incompatibilityReason: "Module requires shell 2.x, current version is 1.0.0")`
- `ModuleUpdater.installUpdate()` called for incompatible module
- Install fails immediately: `InstallResult(success: false, error: "Module incompatible with current shell version")`
- No download attempted (verify via mock HTTP client - no download request made)
- Clear error message displayed to user
- Test suite includes minimum 5 test cases covering: major version mismatch, minor version mismatch (for tilde ranges), exact version mismatch, invalid version range

**Blocking**: Yes (prevents runtime errors from incompatible modules)

---

### AC-10: Module Cache Stores Multiple Versions

**Criterion**: Multiple versions of the same module (e.g., 1.0.0, 1.1.0, 1.2.0) can be stored simultaneously in the cache with proper isolation and cache size tracking.

**test_command**:
```bash
cd C:\Users\bijay\OneDrive\Desktop\auto_agent3\pocs\output\foundry-position-shell-poc && flutter test tests\modules\module_cache_test.dart
```

**pass_condition**:
- Exit code 0 (all tests pass)
- Add v1.0.0 to cache: `ModuleCache.addToCache()` returns `CacheAddResult(success: true)`
- Add v1.1.0 to cache: Returns `success: true`
- Add v1.2.0 to cache: Returns `success: true`
- `ModuleCache.listCachedVersions(moduleId)` returns list containing ["1.0.0", "1.1.0", "1.2.0"] (order may vary)
- Each version has separate directory: `getCachedModulePath(moduleId, "1.0.0")` != `getCachedModulePath(moduleId, "1.1.0")`
- `ModuleCache.getCacheSize()` returns sum of all cached module file sizes (> 0)
- Remove v1.0.0: `removeFromCache(moduleId, "1.0.0")` succeeds
- After removal: `listCachedVersions()` returns ["1.1.0", "1.2.0"] (v1.0.0 removed)
- Cache size decreased after removal
- Test suite includes minimum 6 test cases covering: adding multiple versions, listing versions, size tracking, removal, isolation verification

**Blocking**: Yes (required for fallback and version management)

---

### AC-11: Update Notification Shows in Runtime Host

**Criterion**: When an update is available, a notification UI is displayed in the runtime host with user options to accept or dismiss, and update progress is shown during installation.

**test_command**:
```bash
cd C:\Users\bijay\OneDrive\Desktop\auto_agent3\pocs\output\foundry-position-shell-poc && flutter test integration_test\update_notification_test.dart
```

**pass_condition**:
- Exit code 0 (all tests pass)
- Update available event emitted: `updateEventStream` emits `UpdateEvent(type: updateAvailable, moduleId: "warehouse-clerk", version: "1.1.0")`
- `UpdateNotification.showUpdateAvailable()` called with correct config
- Notification visible: `UpdateNotification.isVisible()` returns true
- User clicks "Update Now": `update-accepted` event emitted
- Update starts: `UpdateNotification.showUpdateProgress()` called
- Progress updates received: `percentComplete` increases from 0 to 100
- Update completes: `UpdateNotification.showUpdateComplete("1.1.0")` called
- User clicks "Dismiss" on completion: Notification dismissed, `isVisible()` returns false
- Test may use mock DOM or headless browser for UI testing
- Test suite includes minimum 5 test cases covering: notification display, user acceptance, progress updates, completion, dismissal

**Blocking**: No (UI enhancement, core functionality works without it)

---

### AC-12: Module Load Uses Cached Version When Available

**Criterion**: When a module version is already cached, it is loaded directly from cache without network access, and load completes in under 200ms.

**test_command**:
```bash
cd C:\Users\bijay\OneDrive\Desktop\auto_agent3\pocs\output\foundry-position-shell-poc && flutter test integration_test\cached_module_load_test.dart
```

**pass_condition**:
- Exit code 0 (all tests pass)
- Module v1.1.0 pre-cached via `ModuleCache.addToCache()`
- `ModuleLoader.loadModule(moduleId: "warehouse-clerk", version: "1.1.0", cachePath: {cached-path})` called
- No network requests made during load (verify via mock HTTP client - zero requests)
- `ModuleLoadResult(success: true, loadDuration: <200)` returned (duration under 200 milliseconds)
- Module initialized successfully: `moduleInfo.hasInitFunction == true`
- Module rendered: `render()` function called successfully
- Correct version loaded: `moduleInfo.version == "1.1.0"`
- Test suite includes minimum 4 test cases covering: cached load performance, no network access, correct version loaded, multiple cached loads

**Blocking**: Yes (core requirement for offline support and performance)

---

## Out Of Scope

The following items are explicitly excluded from Phase 2:

1. **Production CDN Infrastructure**: Module downloads use mock URLs or local test server, not real CDN deployment
2. **Certificate Revocation Checking**: CRL (Certificate Revocation List) and OCSP (Online Certificate Status Protocol) checks not implemented
3. **Delta Updates**: Only full module downloads supported, not incremental/diff-based updates
4. **Automatic Forced Updates**: All updates require user action or explicit opt-in, no forced auto-update
5. **Multi-Tenant Module Variations**: Single module version per release, not tenant-specific variations
6. **Module Dependency Management**: No support for inter-module dependencies (e.g., module A requires module B)
7. **Offline Update Preparation**: Offline-first update queueing covered in Phase 3
8. **Performance Metrics Collection**: No telemetry or analytics for update performance
9. **Module Rollback UI**: Automatic fallback only, no user-initiated manual rollback interface
10. **Module Signing Tool**: Phase 2 assumes pre-signed modules, does not include signing toolchain
11. **Update Scheduling**: Updates are immediate when accepted, no scheduled update windows
12. **Bandwidth Throttling**: Downloads at full speed, no bandwidth limit controls
13. **Cellular Data Warnings**: No differentiation between WiFi and cellular download behavior
14. **Module Preview/Beta Channels**: Single production channel only
15. **Update Approval Workflow**: No admin approval required for updates
16. **Module Uninstall**: Modules can be removed from cache but no formal uninstall flow
17. **Module Permissions System**: All modules have same permission set (covered in future phase)
18. **Rollback Limits**: No limit on number of versions kept (beyond cache size limit)
19. **Update Notification Customization**: Standard notification UI only
20. **Module Health Monitoring**: No crash reporting or health metrics for modules

---

## Dependencies

### Flutter/Dart Packages

Required in `src/shell/pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  # From Phase 1:
  webview_flutter: ^4.4.0
  flutter_secure_storage: ^9.0.0
  crypto: ^3.0.3
  uuid: ^4.2.1
  path_provider: ^2.1.0

  # New for Phase 2:
  pointycastle: ^3.7.0      # RSA signature verification
  http: ^1.1.0              # Module downloads
  semantic_version: ^2.1.0  # Version comparison
  sqflite: ^2.3.0           # SQLite for failure tracking and last-known-good
  path: ^1.8.3              # Path manipulation

dev_dependencies:
  flutter_test:
    sdk: flutter
  integration_test:
    sdk: flutter
  mockito: ^5.4.0           # Mock generation for tests
  build_runner: ^2.4.0      # Code generation for mocks
```

### JavaScript/TypeScript Packages

Required in `src/runtime-host/package.json`:

```json
{
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0"
  },
  "devDependencies": {
    "@types/react": "^18.2.0",
    "@types/react-dom": "^18.2.0",
    "typescript": "^5.3.0",
    "vite": "^5.0.0"
  }
}
```

### System Requirements

- Flutter SDK >=3.0.0
- Dart SDK >=3.0.0
- Node.js >=18.0.0 (for module builds)
- Minimum Android SDK 24 (Android 7.0) or iOS 13.0
- SQLite 3.x (provided by sqflite package)

---

## Risks and Mitigation

### Risk 1: Signature Verification Performance Impact

**Likelihood**: Medium
**Impact**: Medium (200-500ms verification delay per module)

**Mitigation**:
- Cache verification results: Once a module version is verified, store result in database to skip re-verification on subsequent loads
- Async verification: Run verification in background isolate to avoid blocking UI thread
- Verify only on first install: Skip verification for cached modules unless integrity check fails
- Performance target: <100ms for cached verification lookup, <500ms for first-time RSA verification

**Success Criteria**: Module load from cache completes in <200ms including cached verification check

---

### Risk 2: Partial Download Corruption

**Likelihood**: Medium
**Impact**: High (module won't load, user sees error)

**Mitigation**:
- Atomic file operations: Download to `.tmp` file, verify checksum, then rename to final name (atomic on most filesystems)
- Checksum validation: SHA-256 checksum checked before marking download complete
- Cleanup on failure: Failed downloads immediately deleted, no partial files left in cache
- Cleanup on restart: On app launch, scan temp directory and delete any `.tmp` files older than 1 hour
- Retry logic: Automatic retry with exponential backoff for network errors

**Success Criteria**: Zero cases of corrupted modules in cache (100% checksum validation coverage)

---

### Risk 3: Cache Size Growth

**Likelihood**: High
**Impact**: Low (disk space usage, but manageable)

**Mitigation**:
- Keep only last 3 versions per module (configurable, default 3)
- Maximum cache size: 100 MB initial limit (configurable in settings)
- Garbage collection: Automatic cleanup when cache exceeds 90 MB
- Last-known-good protection: Never remove last-known-good versions during GC
- User visibility: Cache size shown in settings, manual "Clear Cache" button available
- LRU eviction: Remove least recently accessed versions first (track lastAccessedAt)

**Success Criteria**: Cache size stays under 100 MB with typical usage (3 modules x 3 versions x ~10 MB = ~90 MB)

---

### Risk 4: Update During Active Session

**Likelihood**: High
**Impact**: Medium (user disruption if handled poorly)

**Mitigation**:
- Download in background: Update download proceeds while module is active
- Defer installation: Downloaded update staged but not installed until module unmount
- User prompt: "Update ready, reload to apply?" notification shown
- Session continuity: User can continue working, update applied on next mount
- Graceful unmount: Module cleanup() called before applying update
- Rollback available: If new version fails after reload, automatic fallback to previous working version

**Success Criteria**: User can complete current task, update applied seamlessly on next module load without data loss

---

### Risk 5: Rollback Loop (Repeatedly Failing Modules)

**Likelihood**: Low
**Impact**: High (infinite loop, poor user experience)

**Mitigation**:
- Failure count tracking: SQLite database tracks failure count per module version
- Failure threshold: After 3 consecutive failures, automatic rollback triggered
- Block threshold: After 5 total failures (including rollback attempts), module blocked until manual intervention
- User notification: Clear error message shown when module blocked: "Module has repeatedly failed to load. Please contact support."
- Detailed logging: Full error stack logged for each failure for diagnostics
- Manual reset: "Reset and Retry" button in settings clears failure count
- Escape hatch: Admin bypass code to force load specific version for debugging

**Success Criteria**: No infinite rollback loops, user always sees actionable error message after 5 failures

---

## Validation Notes

### Cycle 2 Patch Application Summary

This is Validator Cycle 2. All spec_correction changes from patch.md have been applied to address failures found in Cycle 1.

**Patches Applied**:

1. **PATCH-001**: Added dart:async import requirement to D2.1 (Module Downloader) Constraints
   - Addresses FAIL-001: Module Downloader missing import for Completer and TimeoutException
   - Spec now explicitly requires: "Implementation must import dart:async library when using Completer, Future, Stream, TimeoutException, or other async primitives"

2. **PATCH-002**: Added dart:async import requirement to D3.1 (Module Verifier) Constraints
   - Addresses FAIL-002: Module Verifier missing import for TimeoutException
   - Spec now explicitly requires: "Implementation must import dart:async library when using TimeoutException, Completer, or other async error types"

3. **PATCH-003**: Added module_manifest.dart import requirement to D2.2 (Module Updater) Constraints
   - Addresses FAIL-003: Module Updater missing import for ModuleManifest class
   - Spec now explicitly requires: "Implementation must import all referenced types. The ModuleUpdater class uses ModuleManifest and must include: import 'module_manifest.dart'"

4. **PATCH-004**: Added test prerequisites to AC-6 (Module Update Integration Test)
   - Addresses FAIL-004: Integration test blocked by compilation errors in source files
   - Spec now documents: "Test prerequisites: All module update components must compile successfully"

5. **PATCH-005**: Added test file syntax requirements to D8.1-D8.13 Common Test Constraints
   - Addresses FAIL-005: Fallback test file has malformed syntax with mismatched braces
   - Spec now includes test file structure template showing proper setUp/tearDown scoping

6. **PATCH-006**: Added test setup requirements for platform channels to D8.1-D8.13 Common Test Constraints
   - Addresses FAIL-006: Last-known-good test missing TestWidgetsFlutterBinding.ensureInitialized()
   - Spec now requires: "Tests using platform channels must call TestWidgetsFlutterBinding.ensureInitialized()"

7. **PATCH-007**: Added test setup requirements to D8.1-D8.13 Common Test Constraints
   - Addresses FAIL-007: Module cache test missing TestWidgetsFlutterBinding.ensureInitialized()
   - Same constraint as PATCH-006, applied to all tests using path_provider or other platform plugins

8. **PATCH-008**: Added dart:async import requirement to D7.1 (Module Bridge Extension) Constraints
   - Addresses FAIL-008: Module Bridge Extension missing import for TimeoutException
   - Spec now explicitly requires: "Implementation must import dart:async library when using TimeoutException or other async error types"

9. **PATCH-009**: Added integration test execution requirements to D8.1-D8.13 Common Test Constraints
   - Addresses FAIL-009: Cached module load test attempting to run as unit test instead of integration test
   - Spec now documents: "This is an INTEGRATION TEST that requires running on a physical device or emulator"

**General Implementation Constraints Section Added**:
- New section added after Deliverables with comprehensive Dart/Flutter development requirements
- Includes Dart Import Requirements (dart:async, dart:io, dart:convert)
- Includes Flutter Test Requirements (unit vs integration tests, platform channel initialization)
- Includes Code Completion Checklist (flutter analyze, flutter test, import verification)

**Drift Check Status**: APPLIED_PATCHES
- All patches are clarifications and constraint additions only
- No deliverable scopes changed
- No acceptance criteria modified (except AC-6 test prerequisites added)
- No interfaces changed
- No new deliverables added or removed
- All changes are additive (adding missing requirements that were implicit)

### Assumptions Made (validator_mode: assume_and_log)

1. **RSA Key Size**: Assumed RSA-2048 based on industry standard for code signing (balance of security and performance). Documented in `ModuleVerifier` interface. Alternative 4096-bit would double verification time.

2. **Cache Size Limit**: Assumed 100 MB based on typical mobile app cache sizes. Configurable for future adjustment. Rationale: 3 modules x 3 versions x ~10 MB per module = 90 MB typical usage.

3. **Retry Attempts**: Assumed 3 total attempts (1 initial + 2 retries) based on standard HTTP retry practices. Exponential backoff with 2-second base prevents server overload.

4. **Download Timeout**: Assumed 5 minutes (300 seconds) based on 50 MB max module size and minimum 2 Mbps connection speed. Prevents indefinite hangs on slow/stalled connections.

5. **Background Update Interval**: Assumed 4 hours based on typical app usage patterns (balance of freshness vs battery impact). Not during active module use to avoid disruption.

6. **Session Validation**: Reuse Phase 1 `SessionBroker.validateSession()` for bridge method authentication. No new session validation logic needed.

7. **Module Manifest Signature Coverage**: Signature covers concatenated string of `moduleId|version|downloadUrl|checksum` fields. This prevents manifest field tampering while allowing metadata updates.

8. **SQLite for Persistence**: Used sqflite package for failure tracking and last-known-good storage (already common in Flutter ecosystem). Alternative would be shared_preferences but lacks query capability needed for failure tracking.

9. **Version Detection in Module**: Optional `export const MODULE_VERSION` in module code. If missing, version from manifest used. Enables runtime version verification but not required.

10. **Update Progress Calculation**: Download phase = 0-70%, Verification = 70-90%, Installation = 90-100%. Weighted by typical duration of each phase.

11. **Mock CDN URLs**: Phase 2 uses mock download URLs (https://mock-cdn.example.com). Real CDN integration deferred to production deployment phase.

12. **JavaScript Module Format**: ES modules (type="module") for all module code. No CommonJS or UMD support in Phase 2. Aligns with modern JavaScript standards and Vite build output.

13. **Test Framework**: Flutter test framework for all Dart tests. No additional test frameworks introduced. Integration tests use flutter_test integration_test package.

14. **Update Notification UI**: Toast/snackbar style notification based on common mobile UI patterns. Specific design/styling deferred to implementation (not specified in validated spec).

15. **Shell Version Source**: Shell version read from `pubspec.yaml` version field. Standard Flutter practice for version management.

### Ambiguities Resolved

1. **"Fast download"** → Download completes within 5-minute timeout for max 50 MB module at minimum 2 Mbps connection speed
2. **"Secure signature verification"** → RSA-2048 with RSASSA-PKCS1-v1_5 and SHA-256 hash algorithm
3. **"Handle errors"** → All methods return result objects with `{ success: bool, error: string? }` structure, never throw exceptions from public APIs
4. **"Robust retry logic"** → Maximum 3 attempts with exponential backoff (2s, 4s, 8s delays) for network errors only (not 4xx errors)
5. **"Clean cache management"** → Maximum 3 versions per module, 100 MB total cache limit, LRU eviction protecting last-known-good
6. **"Compatible version"** → Semantic version range matching using caret notation (^1.0.0 = >=1.0.0 <2.0.0)

### Edge Cases Added

Every deliverable section includes 10 specific edge cases covering:
- Empty/null/invalid input handling
- Network failure scenarios
- Concurrent operation handling
- Timeout behavior
- Disk full conditions
- Malformed data handling
- State transition edge cases
- Resource cleanup on failure
- Retry exhaustion
- Recovery from corrupted state

### Testability Enhancements

All acceptance criteria now include:
- Exact test commands with full absolute paths
- Specific pass conditions with expected return values and error messages
- Minimum test case counts per test suite
- Expected assertions (e.g., "returns `CompatibilityResult(isCompatible: false)`")
- No test commands use echo, true, exit 0, or other no-ops
- All test commands are executable Flutter test commands
- Integration tests clearly marked and separated from unit tests

### Completeness Verification

✅ All requirements from plan.md mapped to deliverables:
- Version manifest → D1.1, D1.2
- Module update without shell release → D2.1, D2.2, AC-6
- Compatibility check → D4.1, D4.2, AC-2, AC-9
- Provenance and integrity verification → D3.1, D3.2, AC-4
- Last-known-good fallback → D5.2, AC-7, AC-8

✅ All deliverables mapped to acceptance criteria:
- Each deliverable tested by at least one AC
- Critical deliverables (signature verification, compatibility checking) have dedicated ACs
- Integration ACs (AC-6, AC-11, AC-12) test multiple deliverables together

✅ All acceptance criteria have exact test commands and pass conditions
✅ All file paths absolute and complete
✅ All interfaces specified with exact method signatures and return types
✅ All edge cases documented with specific behavior
✅ All error handling specified with exact error messages

---

**END OF VALIDATED SPECIFICATION**
