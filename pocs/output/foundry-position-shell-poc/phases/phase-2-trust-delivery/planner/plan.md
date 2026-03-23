# Phase 2 Trust & Delivery — Detailed Implementation Plan

## PHASE_ID
`phase-2-trust-delivery`

## Phase Name
Trust & Delivery — Module Update System

## What This Phase Builds
Phase 2 establishes the module update delivery system with version management, signature verification, compatibility checking, and automatic fallback mechanisms. This enables position modules to be updated dynamically without requiring Flutter shell reinstallation while maintaining security boundaries and ensuring safe rollback if updates fail.

## Requirements Covered

From Section 6B Slice 2 (Trust and Delivery):
- **Version manifest**: Module registry with version metadata and compatibility requirements
- **Module update without shell release**: Dynamic module download and installation
- **Compatibility check**: Shell version vs module version validation
- **Provenance and integrity verification**: Signature verification for modules
- **CSP/origin/navigation containment**: Enhanced CSP enforcement (already started in Phase 1)
- **Last-known-good fallback**: Automatic rollback when module loads fail

## Deliverables

### 1. Module Version Manifest System
**File**: `src/shell/lib/modules/module_manifest.dart`
- Module metadata structure (moduleId, version, requiredShellVersion, signature, downloadUrl)
- Manifest parsing and validation
- Compatibility range checking (semantic versioning)

**File**: `src/shell/lib/modules/module_registry.dart`
- Module registry service (tracks available modules and versions)
- Available version lookup
- Current installed version tracking
- Module metadata storage

### 2. Module Download and Update Service
**File**: `src/shell/lib/modules/module_downloader.dart`
- HTTP download with progress tracking
- Checksum validation (SHA-256)
- Atomic file operations (download to temp, verify, move)
- Download retry logic with exponential backoff

**File**: `src/shell/lib/modules/module_updater.dart`
- Update orchestration (check → download → verify → install)
- Update notification generation
- Automatic background check mechanism
- Update state machine (checking → available → downloading → installing → complete)

### 3. Signature Verification System
**File**: `src/shell/lib/security/module_verifier.dart`
- Module signature verification (using RSA or Ed25519)
- Public key management (embedded trusted keys)
- Signature format (detached signatures)
- Certificate chain validation

**File**: `src/shell/lib/security/signing_keys.dart`
- Trusted public key storage
- Key rotation support
- Key validation helpers

### 4. Compatibility Checking
**File**: `src/shell/lib/modules/compatibility_checker.dart`
- Shell version detection
- Module requirement parsing (semantic version ranges)
- Compatibility validation logic
- Warning generation for deprecated APIs

**File**: `src/shell/lib/modules/version_resolver.dart`
- Semantic version comparison
- Best compatible version selection
- Update safety checks (major version warnings)

### 5. Module Cache and Fallback System
**File**: `src/shell/lib/modules/module_cache.dart`
- Module cache directory management
- Last-known-good version tracking
- Cache cleanup and garbage collection
- Cache size limits

**File**: `src/shell/lib/modules/fallback_manager.dart`
- Module load failure detection
- Automatic rollback to last-known-good
- Fallback state tracking
- User notification for failed updates

### 6. Enhanced Runtime Host for Versioned Modules
**File**: `src/runtime-host/module-loader.js`
- Dynamic module loading from cache
- Module version detection
- Load failure handling with retry
- Module isolation (separate global scope per version)

**File**: `src/runtime-host/update-notification.js`
- Update UI notification component
- User confirmation for updates
- Update progress indicator
- Error messaging for failed updates

### 7. Bridge Extensions for Module Management
**File**: `src/shell/lib/bridge/module_bridge_extension.dart`
- `checkForUpdates(moduleId)` → UpdateCheckResult
- `getAvailableModules()` → ModuleList
- `getModuleVersion(moduleId)` → VersionInfo
- `installModuleUpdate(moduleId, version)` → InstallResult

### 8. Module Update Tests
**File**: `tests/modules/version_compatibility_test.dart`
- Semantic version range validation
- Incompatible version rejection
- Shell version compatibility checks

**File**: `tests/modules/signature_verification_test.dart`
- Valid signature acceptance
- Invalid signature rejection
- Tampered module detection
- Expired certificate handling

**File**: `tests/modules/update_flow_test.dart`
- Complete update flow (check → download → verify → install)
- Progress tracking validation
- Update cancellation
- Network failure handling

**File**: `tests/modules/fallback_test.dart`
- Failed module load detection
- Automatic rollback to last-known-good
- Multiple fallback attempts
- User notification generation

**File**: `tests/integration/module_update_integration_test.dart`
- End-to-end update scenario
- Concurrent session handling during update
- Update with active module loaded
- Version migration testing

### 9. Sample Updated Module Version
**File**: `src/modules/sample-warehouse/module.manifest.json`
- Module metadata (version 1.1.0)
- Required shell version
- Changelog
- Signature field

**File**: `src/modules/sample-warehouse-v1.1.0/index.tsx`
- Updated module with version indicator in UI
- Demonstrates compatibility with new runtime features

## Architecture Context

### Module Lifecycle with Updates
```
Check for Updates → Download New Version → Verify Signature →
Check Compatibility → Cache Module → Load Module →
[If Load Fails] → Rollback to Last-Known-Good
```

### Security Flow
```
Module Manifest (signed) → Download Module →
Verify SHA-256 Checksum → Verify RSA Signature →
Check Shell Version Compatibility → Install to Cache →
Mark as Last-Known-Good After Successful Load
```

### Version Storage Structure
```
<app_cache>/modules/
  warehouse-clerk/
    1.0.0/
      module.js
      module.manifest.json
      module.signature
    1.1.0/
      module.js
      module.manifest.json
      module.signature
  last-known-good.json
```

## Inputs From Previous Phase

From Phase 1 Foundation:

1. **Working Shell With WebView Host**
   - Interface: `ShellContainer`
   - Type: Dart Class
   - Methods: `launchShell()`, `loadRuntimeHost()`

2. **Tested Bootstrap Mechanism**
   - Interface: `SessionBroker`
   - Type: Dart Service Class
   - Methods: `generateBootstrapCode()`, `redeemBootstrap()`, `validateSession()`

3. **Module Mount/Unmount API**
   - Interface: `RuntimeHostAPI`
   - Type: JavaScript API
   - Methods: `mountModule()`, `unmountModule()`, `getModuleStatus()`

4. **Verified Security Boundary**
   - Interface: `SecurityBoundary`
   - Type: Test Suite
   - Validation: No shell token leakage, bootstrap one-time-use, scoped sessions

## Outputs To Next Phase

Phase 3 will need offline capabilities, so Phase 2 provides:

1. **Module Version Registry**
   - Interface: `ModuleRegistry`
   - Type: Dart Service Class
   - Methods:
     - `getInstalledVersion(moduleId: String): Future<String?>`
     - `getCachedModules(): Future<List<ModuleMetadata>>`
     - `isModuleCached(moduleId: String, version: String): Future<bool>`

2. **Module Cache Manager**
   - Interface: `ModuleCacheManager`
   - Type: Dart Service Class
   - Methods:
     - `getCachedModulePath(moduleId: String, version: String): Future<String?>`
     - `listCachedVersions(moduleId: String): Future<List<String>>`
     - `getCacheSize(): Future<int>`

3. **Update State Tracker**
   - Interface: `UpdateStateTracker`
   - Type: Dart Service Class
   - Methods:
     - `getUpdateState(moduleId: String): Future<UpdateState>`
     - `getPendingUpdates(): Future<List<ModuleUpdate>>`
     - `markUpdateFailed(moduleId: String, reason: String): Future<void>`

4. **Verified Module Storage**
   - Interface: `VerifiedModuleStorage`
   - Type: File System + Database
   - Data: Cached modules with verified signatures, last-known-good versions, compatibility metadata

## Acceptance Criteria

### AC-1: Module Manifest Loads and Parses Correctly
**test_command**:
```bash
cd pocs/output/foundry-position-shell-poc && flutter test test/modules/module_manifest_test.dart
```
**pass_condition**: Manifest parses moduleId, version, requiredShellVersion, signature, downloadUrl successfully; invalid manifests rejected with clear error

### AC-2: Semantic Version Compatibility Check Works
**test_command**:
```bash
cd pocs/output/foundry-position-shell-poc && flutter test test/modules/version_compatibility_test.dart
```
**pass_condition**: Compatible versions accepted (e.g., shell 1.2.0 accepts module requiring ^1.0.0), incompatible versions rejected (e.g., shell 1.0.0 rejects module requiring ^2.0.0)

### AC-3: Module Download Completes with Checksum Validation
**test_command**:
```bash
cd pocs/output/foundry-position-shell-poc && flutter test test/modules/module_download_test.dart
```
**pass_condition**: Module downloads to cache directory, SHA-256 checksum verified, corrupted downloads rejected

### AC-4: Signature Verification Accepts Valid Signatures
**test_command**:
```bash
cd pocs/output/foundry-position-shell-poc && flutter test test/modules/signature_verification_test.dart
```
**pass_condition**: Modules with valid RSA signatures accepted, modules with invalid/missing signatures rejected, tampered modules detected

### AC-5: Update Check Detects Available Updates
**test_command**:
```bash
cd pocs/output/foundry-position-shell-poc && flutter test test/modules/update_check_test.dart
```
**pass_condition**: Registry checked, newer compatible version detected, update availability reported with version details

### AC-6: Module Update Installs Without Shell Reinstall
**test_command**:
```bash
cd pocs/output/foundry-position-shell-poc && flutter test integration_test/module_update_test.dart
```
**pass_condition**: Module v1.0.0 installed, update to v1.1.0 downloaded and verified, new version loaded without app restart

### AC-7: Failed Module Load Triggers Automatic Fallback
**test_command**:
```bash
cd pocs/output/foundry-position-shell-poc && flutter test test/modules/fallback_test.dart
```
**pass_condition**: Corrupted module fails to load, fallback manager automatically loads last-known-good version, user notified of fallback

### AC-8: Last-Known-Good Version Persists After Successful Load
**test_command**:
```bash
cd pocs/output/foundry-position-shell-poc && flutter test test/modules/last_known_good_test.dart
```
**pass_condition**: Module v1.1.0 loads successfully, marked as last-known-good, persisted to storage for future fallback

### AC-9: Incompatible Module Version Rejected Before Download
**test_command**:
```bash
cd pocs/output/foundry-position-shell-poc && flutter test test/modules/compatibility_rejection_test.dart
```
**pass_condition**: Module requiring shell v2.0.0 rejected on shell v1.0.0, clear error message shown, no download attempted

### AC-10: Module Cache Stores Multiple Versions
**test_command**:
```bash
cd pocs/output/foundry-position-shell-poc && flutter test test/modules/module_cache_test.dart
```
**pass_condition**: Multiple versions (1.0.0, 1.1.0, 1.2.0) stored in cache, each version isolated, cache size tracked

### AC-11: Update Notification Shows in Runtime Host
**test_command**:
```bash
cd pocs/output/foundry-position-shell-poc && flutter test integration_test/update_notification_test.dart
```
**pass_condition**: Update available event triggers UI notification, user can accept/dismiss, update progress shown

### AC-12: Module Load Uses Cached Version When Available
**test_command**:
```bash
cd pocs/output/foundry-position-shell-poc && flutter test integration_test/cached_module_load_test.dart
```
**pass_condition**: Module loaded from cache (no network call), load completes in <200ms, correct version loaded

## Technical Approach

### Technology Stack
- **Flutter crypto package** for SHA-256 and RSA signature verification
- **pointycastle** for cryptographic operations
- **http package** for module downloads
- **path_provider** for cache directory management
- **semantic_version** package for version comparison

### Security Model
```
Manifest Signature Verification → Module Download →
Checksum Validation → Compatibility Check →
Secure Cache Storage → Last-Known-Good Tracking
```

### Module Versioning Strategy
- Semantic versioning (MAJOR.MINOR.PATCH)
- Compatibility ranges using semver notation (^1.0.0, >=2.1.0)
- Shell version in module manifest
- Module version in runtime contract

### Update Delivery Flow
1. Background check for updates (every 4 hours or on app launch)
2. Download compatible updates to temporary directory
3. Verify signature and checksum
4. Install to cache atomically
5. Notify user of available update
6. Load new version on next module mount (or prompt for immediate reload)

## Out Of Scope

- Real CDN infrastructure (mock download URLs)
- Certificate revocation checking (CRL/OCSP)
- Delta updates (full module download only)
- Automatic forced updates
- Multi-tenant module variations
- Module dependency management between modules
- Offline update preparation (covered in Phase 3)
- Performance metrics collection

## Dependencies

- Flutter SDK >=3.0.0
- pointycastle ^3.7.0 (cryptography)
- crypto ^3.0.3 (hashing)
- http ^1.1.0 (downloads)
- path_provider ^2.1.0 (cache paths)
- semantic_version ^2.1.0 (version comparison)

## Risks and Mitigation

### Risk 1: Signature Verification Performance Impact
**Mitigation**: Cache verification results, verify only on first install, use async verification to avoid UI blocking

### Risk 2: Partial Download Corruption
**Mitigation**: Atomic file operations (write to .tmp, verify, rename), cleanup incomplete downloads on app restart

### Risk 3: Cache Size Growth
**Mitigation**: Keep only last 2 versions per module, implement garbage collection, set maximum cache size (100MB initial limit)

### Risk 4: Update During Active Session
**Mitigation**: Download in background but defer installation until module unmount, prompt user for reload, maintain session continuity

### Risk 5: Rollback Loop (Repeatedly Failing Modules)
**Mitigation**: Track failure count, disable auto-retry after 3 failures, require manual user intervention, log detailed error diagnostics
