# Phase 3 — Offline-Critical Workflow

PHASE_ID: phase-3-offline-critical-workflow
PLANNER_DOC_VERSION: 6.1.0
DEPENDS_ON: phase-2-trust-delivery
PROVIDES_TO: phase-4-high-trust-native-capabilities

## What This Phase Builds

Phase 3 completes the offline-first architecture by integrating Phase 2's cache infrastructure into the module loading flow, implementing local data persistence with automatic sync, and adding network state management. When complete, users can perform warehouse workflows entirely offline with zero data loss, modules load from cache in under 200ms, and all offline operations sync automatically when connectivity returns.

## Requirements Covered

### From foundry-position-shell-parity-evaluation.md (Section 6B, Slice 3)

- REQ-OFFLINE-1: "offline launch" - Module loads from cache when network unavailable
- REQ-OFFLINE-2: "local persistence" - User actions persist locally during offline operation
- REQ-OFFLINE-3: "one scan-driven transaction path" - Minimal workflow proves offline capability
- REQ-OFFLINE-4: "reconnect and sync recovery" - Automatic sync when network returns
- REQ-OFFLINE-5: "cached relaunch" - Module cache survives app restart

### From foundry-position-shell-poc-scenarios.md

- **Scenario W-3**: Full offline receiving transaction - Complete 50-line receiving transaction with zero connectivity, all data persisted locally, sync executes automatically on reconnect with no data loss
- **Scenario W-4**: Offline-first launch - Device in airplane mode, app opens, module loads from cache, previous data visible, new transactions queue locally
- **Scenario W-5**: Asset/page caching - Second load of position module < 200ms from local cache, no network request for cached assets, cache survives app restart
- **Scenario X-11**: Bad module update rollback - Incompatible or tampered module is rejected, last-known-good module remains available from cache without reinstall

### From Phase 2 ADR-001

- REQ-CACHE-INT-1: Wire ModuleCache into WebView module loading flow
- REQ-CACHE-INT-2: Implement download → verify → cache → load pipeline
- REQ-CACHE-INT-3: Implement cache lookup before network requests
- REQ-CACHE-INT-4: Measure and verify < 200ms cache load threshold on device
- REQ-CACHE-INT-5: Test offline loading with network disabled

### From Phase 2 Plan (Periodic Updates)

- REQ-UPDATE-1: Background registry checks (every 4 hours)
- REQ-UPDATE-2: Network reconnect triggers registry check
- REQ-UPDATE-3: Position switch triggers update check

## Deliverables

### Core Integration (Complete ADR-001)

- [ ] `src/shell/lib/modules/module_loader.dart`: Central module loading orchestration with cache-first strategy
- [ ] `src/shell/lib/modules/cached_module_loader.dart`: Cache-optimized loading path (< 200ms target)
- [ ] Update `src/shell/lib/runtime_host/runtime_host_bridge.dart`: Integrate module loader with WebView runtime
- [ ] Performance measurement utility for cache load timing

### Network State Management

- [ ] `src/shell/lib/network/network_monitor.dart`: Network connectivity detection and state changes
- [ ] `src/shell/lib/network/network_state.dart`: Network state model (online, offline, reconnecting)
- [ ] Network change event stream for reactive updates

### Offline Data Persistence

- [ ] `src/shell/lib/offline/offline_transaction_queue.dart`: Queue for offline operations with SQLite backing
- [ ] `src/shell/lib/offline/sync_manager.dart`: Automatic sync orchestration on network return
- [ ] `src/shell/lib/offline/conflict_resolver.dart`: Last-write-wins conflict resolution for POC
- [ ] Database schema migration for transaction queue tables

### Periodic Update System

- [ ] `src/shell/lib/modules/update_scheduler.dart`: Background update checks (4-hour intervals)
- [ ] `src/shell/lib/modules/update_trigger.dart`: Trigger logic for reconnect and position switch
- [ ] Integration with existing UpdateStateTracker from Phase 2

### Bridge Extensions for Offline

- [ ] `src/shell/lib/bridge/offline_bridge_extension.dart`: Bridge methods for offline status and queue visibility
  - `getNetworkState() → NetworkState`
  - `getPendingSyncCount() → int`
  - `forceSyncNow() → SyncResult`

### Integration Tests

- [ ] `integration_test/offline_module_load_test.dart`: Module loads from cache in airplane mode, measures < 200ms performance
- [ ] `integration_test/offline_data_persistence_test.dart`: Create transaction offline, verify SQLite storage, sync on reconnect
- [ ] `integration_test/network_reconnect_test.dart`: Simulate offline → online transition, verify auto-sync
- [ ] `integration_test/periodic_update_check_test.dart`: Verify 4-hour update checks trigger correctly
- [ ] `integration_test/cache_survival_test.dart`: Verify cache persists across app restarts

### Documentation

- [ ] Update `phases/phase-3-offline-critical-workflow/planner/INTEGRATION_GUIDE.md`: How offline features integrate with Phase 2 services
- [ ] Performance benchmark results (cache load time measurements)

## Inputs From Previous Phase

From Phase 2 (Trust & Delivery):

### ModuleCache Interface
```dart
class ModuleCache {
  Future<String?> getCachedModulePath(String moduleId, String version);
  Future<List<String>> listCachedVersions(String moduleId);
  Future<int> getCacheSize();
  Future<String> getCacheDirectory();
  Future<void> runGarbageCollection();
  Future<void> storeModule(String moduleId, String version, String sourcePath);
}
```

### ModuleRegistry Interface
```dart
class ModuleRegistry {
  Future<String?> getInstalledVersion(String moduleId);
  Future<List<ModuleMetadata>> getAvailableModules();
  Future<List<String>> getCachedVersions(String moduleId);
  bool get isRegistryLoaded;
  Future<void> loadRegistry(String manifestUrl);
}
```

### FallbackManager Interface
```dart
class FallbackManager {
  Future<String?> getLastKnownGoodVersion(String moduleId);
  Future<int> getFailureCount(String moduleId, String version);
  Future<bool> isBlocked(String moduleId, String version);
  Future<void> recordLoadFailure(String moduleId, String version, String error);
  Future<void> markAsLastKnownGood(String moduleId, String version);
  Future<void> resetFailures(String moduleId, String version);
}
```

### ModuleVerifier Interface
```dart
class ModuleVerifier {
  Future<VerificationResult> verifyModule(String modulePath, ModuleMetadata metadata);
  Future<bool> verifySignature(File signatureFile, File moduleFile);
}
```

### UpdateStateTracker Interface
```dart
class UpdateStateTracker {
  UpdateState getUpdateState(String moduleId);
  Future<Map<String, UpdateCheckResult>> checkAllModulesForUpdates();
  Stream<UpdateEvent> get updateEventStream;
  Future<void> installModuleUpdate(String moduleId, String version);
}
```

### ModuleDownloader Interface
```dart
class ModuleDownloader {
  Future<String> download(String url, String moduleId, String version);
  Future<void> cancelDownload(String moduleId);
  Stream<DownloadProgress> getProgressStream(String moduleId);
}
```

## Outputs To Next Phase

To Phase 4 (High-Trust & Native Capabilities):

### ModuleLoader Interface
```dart
class ModuleLoader {
  Future<LoadResult> loadModule(String moduleId, {String? version});
  Future<void> unloadModule(String moduleId);
  Future<bool> isModuleCached(String moduleId, String version);
  Future<Duration> getLastLoadTime(String moduleId);
  Stream<ModuleLoadEvent> get loadEventStream;
}
```

### NetworkMonitor Interface
```dart
class NetworkMonitor {
  NetworkState get currentState;
  Stream<NetworkState> get stateChanges;
  Future<bool> isOnline();
  Future<NetworkType> getNetworkType();
}
```

### OfflineTransactionQueue Interface
```dart
class OfflineTransactionQueue {
  Future<void> enqueue(OfflineTransaction transaction);
  Future<List<OfflineTransaction>> getPendingTransactions();
  Future<int> getPendingCount();
  Future<void> markSynced(String transactionId);
  Stream<SyncEvent> get syncEventStream;
}
```

### SyncManager Interface
```dart
class SyncManager {
  Future<SyncResult> syncNow();
  Future<bool> isSyncing();
  Future<DateTime?> getLastSyncTime();
  Future<void> pauseAutoSync();
  Future<void> resumeAutoSync();
  Stream<SyncProgress> get syncProgressStream;
}
```

### UpdateScheduler Interface
```dart
class UpdateScheduler {
  Future<void> start();
  Future<void> stop();
  Future<DateTime?> getNextCheckTime();
  Future<void> checkNow();
  Duration get checkInterval; // 4 hours
}
```

## Acceptance Criteria

### AC-3.1: Module Cache Integration Complete
**Criterion**: Module loading flow uses ModuleCache for all module loads, checking cache before network downloads

**Test Command**: `flutter test test/modules/module_loader_test.dart --name "cache-first strategy"`

**Pass Condition**: Exit code 0, test output contains "Cache checked before download", "Cached module loaded without network request"

**Blocking**: true

---

### AC-3.2: Cached Module Load Performance < 200ms
**Criterion**: Second load of a cached module completes in under 200ms on target device (Android emulator)

**Test Command**: `flutter test integration_test/offline_module_load_test.dart --name "cached load performance"`

**Pass Condition**: Exit code 0, test output contains "Cache load time: [0-1][0-9][0-9]ms" (regex match < 200ms)

**Blocking**: true

---

### AC-3.3: Offline Module Loading Works
**Criterion**: Module loads successfully from cache when network is disabled (airplane mode simulation)

**Test Command**: `flutter test integration_test/offline_module_load_test.dart --name "offline load"`

**Pass Condition**: Exit code 0, test output contains "Module loaded offline", "No network requests made", "Cache hit: sample-warehouse"

**Blocking**: true

---

### AC-3.4: Cache Survives App Restart
**Criterion**: Cached modules remain available after app restart, no re-download required

**Test Command**: `flutter test integration_test/cache_survival_test.dart`

**Pass Condition**: Exit code 0, test output contains "Cache persisted across restart", "Module loaded from cache after restart"

**Blocking**: true

---

### AC-3.5: Download → Verify → Cache → Load Pipeline Works
**Criterion**: First module load downloads, verifies signature, stores in cache, and loads successfully

**Test Command**: `flutter test integration_test/module_download_pipeline_test.dart`

**Pass Condition**: Exit code 0, test output contains "Module downloaded", "Signature verified", "Stored in cache", "Module loaded"

**Blocking**: true

---

### AC-3.6: Network State Detection Works
**Criterion**: NetworkMonitor correctly detects online/offline state and emits state change events

**Test Command**: `flutter test test/network/network_monitor_test.dart`

**Pass Condition**: Exit code 0, test output contains "Online state detected", "Offline state detected", "State change event emitted"

**Blocking**: true

---

### AC-3.7: Offline Transaction Queue Persists Data
**Criterion**: Offline transactions are saved to SQLite database and survive app restart

**Test Command**: `flutter test integration_test/offline_data_persistence_test.dart --name "queue persistence"`

**Pass Condition**: Exit code 0, test output contains "Transaction queued", "Persisted to SQLite", "Survived app restart"

**Blocking**: true

---

### AC-3.8: Automatic Sync On Network Reconnect
**Criterion**: When network state changes from offline → online, SyncManager automatically syncs queued transactions

**Test Command**: `flutter test integration_test/network_reconnect_test.dart`

**Pass Condition**: Exit code 0, test output contains "Network reconnected", "Auto-sync triggered", "Transactions synced successfully"

**Blocking**: true

---

### AC-3.9: Zero Data Loss In Offline Mode
**Criterion**: User can create 50 offline transactions, all persist locally, all sync successfully when online

**Test Command**: `flutter test integration_test/offline_data_persistence_test.dart --name "zero data loss"`

**Pass Condition**: Exit code 0, test output contains "50 transactions created offline", "50 transactions persisted", "50 transactions synced", "0 lost"

**Blocking**: true

---

### AC-3.10: Periodic Update Checks Every 4 Hours
**Criterion**: UpdateScheduler triggers registry checks every 4 hours when app is running

**Test Command**: `flutter test integration_test/periodic_update_check_test.dart`

**Pass Condition**: Exit code 0, test output contains "Update check triggered", "4 hour interval verified", "Registry checked"

**Blocking**: true

---

### AC-3.11: Network Reconnect Triggers Update Check
**Criterion**: When network state changes to online, update check is triggered automatically

**Test Command**: `flutter test test/modules/update_trigger_test.dart --name "reconnect trigger"`

**Pass Condition**: Exit code 0, test output contains "Network reconnected", "Update check triggered", "Registry checked for updates"

**Blocking**: true

---

### AC-3.12: Conflict Resolution Works (Last-Write-Wins)
**Criterion**: When offline and online data conflict, last-write-wins strategy resolves correctly

**Test Command**: `flutter test test/offline/conflict_resolver_test.dart`

**Pass Condition**: Exit code 0, test output contains "Conflict detected", "Last-write-wins applied", "Latest data preserved"

**Blocking**: false

---

### AC-3.13: Bridge Offline Status API Works
**Criterion**: Position modules can query network state and pending sync count via bridge

**Test Command**: `flutter test test/bridge/offline_bridge_extension_test.dart`

**Pass Condition**: Exit code 0, test output contains "getNetworkState returned: offline", "getPendingSyncCount returned: 5"

**Blocking**: true

---

### AC-3.14: No Regression In Phase 2 Tests
**Criterion**: All 70 Phase 2 tests continue to pass after Phase 3 changes

**Test Command**: `flutter test test/ && flutter test integration_test/signature_verification_test.dart integration_test/fallback_test.dart integration_test/last_known_good_test.dart integration_test/module_cache_test.dart integration_test/cached_module_load_test.dart`

**Pass Condition**: Exit code 0, test output contains "70 passed, 0 failed"

**Blocking**: true

---

### AC-3.15: App Launch Verification
**Criterion**: App launches successfully on Android emulator with offline mode enabled

**Test Command**: `flutter run --release -d emulator-5554 & sleep 10 && adb shell dumpsys activity | grep "mResumedActivity"`

**Pass Condition**: Exit code 0, output contains app package name, app is in resumed state

**Blocking**: true

## Manual Test Steps

### Test 1: Offline Module Loading
1. Launch app with network enabled → Expected: Module downloads and loads
2. Close app
3. Enable airplane mode on device
4. Launch app → Expected: Module loads from cache in < 200ms, no network errors
5. Navigate to module → Expected: Module UI renders correctly
6. Check logs → Expected: "Cache hit: sample-warehouse", "Load time: <200ms"

### Test 2: Offline Transaction Persistence
1. Launch app in airplane mode
2. Create a new warehouse transaction (scan items, enter quantities)
3. Submit transaction → Expected: "Queued for sync" message shown
4. Close app
5. Relaunch app in airplane mode → Expected: Transaction still visible in queue
6. Disable airplane mode
7. Wait 5 seconds → Expected: "Sync complete" notification, transaction marked as synced
8. Check backend → Expected: Transaction present in server database

### Test 3: Network Reconnect Auto-Sync
1. Create 10 transactions offline
2. Verify pending sync count shows 10
3. Disable airplane mode → Expected: Sync starts automatically within 1 second
4. Progress indicator shows sync status
5. All 10 transactions sync successfully
6. Pending count returns to 0

### Test 4: Periodic Update Check
1. Launch app
2. Note current time
3. Wait 4 hours (or simulate with time injection)
4. Check logs → Expected: "Periodic update check triggered", "Registry checked"
5. If updates available → Expected: Notification shown

### Test 5: Cache Performance Measurement
1. Clear cache: `adb shell pm clear com.foundry.position_shell`
2. Launch app → Expected: Module downloads (first load)
3. Note load time in logs
4. Close and relaunch app → Expected: Module loads from cache
5. Note load time → Expected: < 200ms
6. Verify no network request made (check network logs)

## Phase Achievement

When Phase 3 passes, the user can perform complete warehouse receiving workflows entirely offline, with all data persisted locally and automatically synced when connectivity returns, while modules load from cache in under 200ms.

## Out Of Scope

Phase 3 does NOT include:

- Biometric authentication (Phase 4: High-Trust Workflows)
- Role switching security enhancements (Phase 4)
- Camera/barcode scanning implementation (Phase 4: Rich Device Workflow)
- Photo capture and attachment (Phase 4)
- Bluetooth scanner integration (Phase 4)
- Bluetooth printing (Phase 4)
- NFC tag reading (Phase 4)
- Push notification handling (Phase 4)
- Background data refresh (Phase 4)
- Performance profiling infrastructure (Phase 5)
- App store policy validation (Phase 5)
- Production CDN infrastructure (always mock URLs)
- Complex conflict resolution strategies beyond last-write-wins
- Multi-user offline collaboration
- Delta sync optimization (full sync only)
- Offline module updates (download only when online)

## Dependencies

### Required Flutter/Dart Packages
- `connectivity_plus: ^5.0.0` - Network state monitoring
- `sqflite: ^2.3.0` - Already integrated in Phase 2 (FallbackManager)
- `path_provider: ^2.1.0` - Already integrated in Phase 2
- `http: ^1.1.0` - Already integrated in Phase 2

### Required Platform Channels
- Network state (via connectivity_plus)
- SQLite database (via sqflite)
- File system (via path_provider)

### Phase 2 Services (Dependencies)
- ModuleCache (complete integration required)
- ModuleRegistry (add periodic checks)
- FallbackManager (reuse for offline transactions)
- ModuleVerifier (unchanged)
- UpdateStateTracker (add trigger mechanisms)
- ModuleDownloader (unchanged)

## Risks and Mitigation

### Risk 1: Cache Integration Breaks Existing Module Loading
**Impact**: High - Could break Phase 1 and Phase 2 functionality
**Mitigation**:
- Implement cache-first strategy as additive enhancement
- Keep bundled module loading as fallback
- Run full Phase 2 test suite after integration
- Use feature flag to enable/disable cache integration during testing

### Risk 2: < 200ms Cache Load Threshold Not Achievable
**Impact**: Medium - Performance requirement miss
**Mitigation**:
- Profile cache load path to identify bottlenecks
- Optimize file I/O (memory-mapped files, read-ahead)
- Pre-warm cache on app startup
- Use background thread for cache operations
- Measure on real device, not just emulator

### Risk 3: SQLite Contention Between Offline Queue and FallbackManager
**Impact**: Medium - Database locking could slow down operations
**Mitigation**:
- Use separate database files (fallback.db, offline_queue.db)
- WAL mode for concurrent reads/writes
- Connection pooling
- Batch transaction writes

### Risk 4: Network State Detection Unreliable
**Impact**: High - Auto-sync might not trigger
**Mitigation**:
- Use connectivity_plus package (proven reliability)
- Implement heartbeat checks (ping server every 30s when online)
- Add manual "Sync Now" button as fallback
- Handle network state transitions gracefully (debounce rapid changes)

### Risk 5: Periodic Update Checks Drain Battery
**Impact**: Low - Background timers can impact battery life
**Mitigation**:
- Use WorkManager-style scheduling (platform-optimized)
- Only check when app is in foreground or charging
- WiFi-only update downloads by default
- Allow user to disable background checks

### Risk 6: Offline Data Grows Unbounded
**Impact**: Medium - Storage exhaustion over time
**Mitigation**:
- Implement sync success cleanup (delete synced transactions after 7 days)
- Set maximum queue size (1000 transactions)
- Show storage usage to user
- Garbage collection on app startup

### Risk 7: Time-Based Test Flakiness (4-hour check)
**Impact**: Medium - Periodic update tests might be unreliable
**Mitigation**:
- Use time injection for tests (mock Timer/Duration)
- Test with accelerated intervals (10 seconds instead of 4 hours)
- Verify scheduling logic separately from actual wait time
- Use fake_async package for deterministic time tests

## Planner Notes

⚠ UNCLEAR: "Conflict resolution strategy" - Requirements specify "zero data loss" but don't define conflict resolution behavior when offline and online versions of same transaction differ. Implementing last-write-wins for POC scope, but Validator should confirm this is acceptable or define alternative strategy.

⚠ UNCLEAR: "Sync on reconnect" timing - Should sync start immediately on network reconnect (within 1 second) or wait for user action? Implementing immediate auto-sync for better UX, but Validator should confirm.

⚠ UNCLEAR: "50-line receiving transaction" - Scenario W-3 mentions 50 lines but doesn't define transaction structure. Assuming simple transaction model (id, timestamp, items[], quantities[]) for POC. Validator should confirm or provide schema.
