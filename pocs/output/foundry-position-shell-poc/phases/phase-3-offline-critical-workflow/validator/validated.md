# Validated Spec — Phase 3: Offline-Critical Workflow

PHASE_ID: phase-3-offline-critical-workflow
VALIDATED: 2026-03-16T15:10:00Z
VALIDATOR_CYCLE: 1
VALIDATOR_DOC_VERSION: 6.1.0
DRIFT_CHECK_STATUS: NOT_APPLICABLE

## What To Build

Phase 3 delivers complete offline-first capability by integrating Phase 2's ModuleCache into the module loading flow, implementing SQLite-backed transaction persistence, and adding network state management with automatic synchronization.

**Cache Integration**: The WebView module loading path must check ModuleCache.getCachedModulePath() before initiating any network download. On cache hit, module loads directly from filesystem (target: under 200 milliseconds measured from load request to WebView ready state). On cache miss, the system downloads the module, verifies signature using ModuleVerifier from Phase 2, stores in cache using ModuleCache.storeModule(), then loads from cache.

**Offline Data Persistence**: A transaction queue backed by SQLite database stores all user actions when network is unavailable. Each transaction record includes: transaction_id (UUID), module_id (string), timestamp (Unix epoch milliseconds), payload (JSON string), sync_status (enum: pending, syncing, synced, failed), retry_count (integer), and last_error (string nullable). Maximum queue size is 1000 transactions. When queue reaches 900 transactions, user receives warning. At 1000, user cannot create new transactions until sync completes.

**Network State Management**: NetworkMonitor service uses connectivity_plus package to detect network availability. Network states are: online (internet reachable), offline (no connectivity), reconnecting (transitioning from offline to online). State changes emit events to NetworkMonitor.stateChanges stream. On reconnect event (offline → online transition), SyncManager automatically triggers sync within 1 second.

**Automatic Sync**: SyncManager processes transaction queue in batches of 50 transactions per HTTP request. Sync uses last-write-wins conflict resolution (server timestamp compared to transaction timestamp, newer wins). On sync failure, transaction remains in queue with incremented retry_count. After 3 failed sync attempts, transaction moves to failed_transactions table and user notification appears.

**Periodic Update Checks**: UpdateScheduler runs a Timer at 4-hour intervals (14400000 milliseconds) when app is in foreground. On each interval, calls ModuleRegistry.loadRegistry() to fetch latest manifest, then calls UpdateStateTracker.checkAllModulesForUpdates(). If updates available, emits notification via UpdateEvent stream. Network reconnect also triggers immediate update check. Position switch (user changes role) triggers update check.

**Performance Requirements**: Cached module load must complete in under 200 milliseconds measured from ModuleLoader.loadModule() call to onModuleReady callback. Measurement uses Stopwatch from dart:core. Network state detection latency must be under 1 second from actual connectivity change to NetworkMonitor event emission. Sync initiation must occur within 1 second of reconnect event.

**Integration Requirements**: All Phase 2 services remain functional. All 70 Phase 2 tests continue passing. No changes to signature verification logic (ModuleVerifier). No changes to fallback mechanism (FallbackManager). Bridge API remains backward compatible.

## Deliverables

### ModuleLoader Service
- **type**: service
- **path**: `src/shell/lib/modules/module_loader.dart`
- **purpose**: Orchestrates module loading with cache-first strategy, integrating ModuleCache, ModuleDownloader, and ModuleVerifier
- **interface**:
  ```dart
  class ModuleLoader {
    Future<LoadResult> loadModule(String moduleId, {String? version}) async;
    Future<void> unloadModule(String moduleId) async;
    Future<bool> isModuleCached(String moduleId, String version) async;
    Future<Duration> getLastLoadTime(String moduleId) async;
    Stream<ModuleLoadEvent> get loadEventStream;
  }

  class LoadResult {
    final bool success;
    final String? modulePath;
    final Duration loadTime;
    final String? error;
    final LoadSource source; // enum: cache, download
  }
  ```
- **constraints**:
  - Cache load time must be < 200ms (measured with Stopwatch)
  - Network timeout for downloads: 30 seconds
  - Maximum concurrent module loads: 1 (sequential loading)
  - Failed loads recorded via FallbackManager.recordLoadFailure()
- **edge_cases**:
  - Module not in cache and network offline: return LoadResult with error "Module not available offline"
  - Download interrupted mid-transfer: cleanup temp files, return error
  - Signature verification fails: delete downloaded file, do not cache, return error
  - Cache file corrupted (read error): delete cache entry, re-download if online

### CachedModuleLoader Helper
- **type**: component
- **path**: `src/shell/lib/modules/cached_module_loader.dart`
- **purpose**: Optimized cache reading path for sub-200ms performance
- **interface**:
  ```dart
  class CachedModuleLoader {
    Future<String> loadFromCache(String cachedPath) async;
    Future<void> preloadModule(String moduleId, String version) async;
  }
  ```
- **constraints**:
  - Uses memory-mapped file reading for large modules (> 1MB)
  - Pre-warms cache on app startup (loads manifests only)
  - Returns module content as UTF-8 string for WebView.evaluateJavascript()
- **edge_cases**:
  - File read permission denied: throw FileSystemException with specific message
  - File deleted between cache check and load: return error, invalidate cache entry
  - File encoding is not UTF-8: attempt ISO-8859-1 fallback, else error

### NetworkMonitor Service
- **type**: service
- **path**: `src/shell/lib/network/network_monitor.dart`
- **purpose**: Detects network connectivity changes and exposes current network state
- **interface**:
  ```dart
  class NetworkMonitor {
    NetworkState get currentState;
    Stream<NetworkState> get stateChanges;
    Future<bool> isOnline() async;
    Future<NetworkType> getNetworkType() async; // wifi, cellular, none
    Future<void> dispose() async;
  }

  enum NetworkState { online, offline, reconnecting }
  enum NetworkType { wifi, cellular, ethernet, vpn, none }
  ```
- **constraints**:
  - State change detection latency: < 1 second
  - Uses connectivity_plus package ^5.0.0
  - Debounces rapid state changes (minimum 500ms between emitted events)
  - Runs connectivity check heartbeat every 30 seconds when in online state
- **edge_cases**:
  - Connectivity package reports online but internet unreachable: ping 1.1.1.1, mark offline if ping fails
  - Rapid connect/disconnect cycles: debounce to prevent state change spam
  - App suspended while offline: on resume, immediately check current state
  - VPN connection detected: treat as online if internet reachable

### NetworkState Model
- **type**: file
- **path**: `src/shell/lib/network/network_state.dart`
- **purpose**: Enum and helper classes for network state representation
- **interface**:
  ```dart
  enum NetworkState {
    online,    // internet reachable
    offline,   // no connectivity
    reconnecting  // transitioning from offline to online
  }

  class NetworkStateChange {
    final NetworkState previousState;
    final NetworkState currentState;
    final DateTime timestamp;
  }
  ```
- **constraints**:
  - Immutable state objects
  - Timestamp in UTC timezone
  - Serializable to JSON for logging
- **edge_cases**: None (simple enum)

### OfflineTransactionQueue Service
- **type**: service
- **path**: `src/shell/lib/offline/offline_transaction_queue.dart`
- **purpose**: Persists offline user actions to SQLite database for later sync
- **interface**:
  ```dart
  class OfflineTransactionQueue {
    Future<void> enqueue(OfflineTransaction transaction) async;
    Future<List<OfflineTransaction>> getPendingTransactions() async;
    Future<int> getPendingCount() async;
    Future<void> markSynced(String transactionId) async;
    Future<void> markFailed(String transactionId, String error) async;
    Stream<SyncEvent> get syncEventStream;
    Future<void> dispose() async;
  }

  class OfflineTransaction {
    final String transactionId; // UUID
    final String moduleId;
    final int timestamp; // Unix epoch milliseconds
    final String payload; // JSON string
    SyncStatus syncStatus;
    int retryCount;
    String? lastError;
  }

  enum SyncStatus { pending, syncing, synced, failed }
  ```
- **constraints**:
  - Maximum queue size: 1000 transactions
  - Warning threshold: 900 transactions
  - Database file: `offline_transactions.db` in app support directory
  - Database schema version: 1
  - Atomic transaction writes (wrap in SQL transaction)
- **edge_cases**:
  - Queue full (1000 transactions): throw QueueFullException with message "Offline queue full. Sync required."
  - Database file corrupted: attempt recovery, if fails create new database (data loss)
  - Concurrent enqueue from multiple isolates: use database-level locking
  - Transaction payload > 1MB: throw PayloadTooLargeException

### SyncManager Service
- **type**: service
- **path**: `src/shell/lib/offline/sync_manager.dart`
- **purpose**: Orchestrates automatic synchronization of offline transactions when network returns
- **interface**:
  ```dart
  class SyncManager {
    Future<SyncResult> syncNow() async;
    Future<bool> isSyncing() async;
    Future<DateTime?> getLastSyncTime() async;
    Future<void> pauseAutoSync() async;
    Future<void> resumeAutoSync() async;
    Stream<SyncProgress> get syncProgressStream;
    Future<void> dispose() async;
  }

  class SyncResult {
    final int totalTransactions;
    final int syncedCount;
    final int failedCount;
    final Duration duration;
    final List<SyncError> errors;
  }

  class SyncProgress {
    final int total;
    final int current;
    final double percentComplete;
  }
  ```
- **constraints**:
  - Batch size: 50 transactions per HTTP POST
  - Sync endpoint: `https://api.foundry.example.com/v1/sync/transactions` (mock for POC)
  - Timeout per batch: 30 seconds
  - Maximum retry attempts per transaction: 3
  - Auto-sync triggers: network reconnect, manual user request, app foreground
- **edge_cases**:
  - Sync in progress when user triggers manual sync: return existing sync operation (don't start duplicate)
  - Network disconnects during sync: pause sync, resume on reconnect from last completed batch
  - Server returns 409 Conflict: apply conflict resolution (last-write-wins), mark synced
  - Server returns 500: increment retry_count, keep in queue, try again on next sync

### ConflictResolver Component
- **type**: component
- **path**: `src/shell/lib/offline/conflict_resolver.dart`
- **purpose**: Resolves conflicts between offline and online data using last-write-wins strategy
- **interface**:
  ```dart
  class ConflictResolver {
    Future<ConflictResolution> resolve(OfflineTransaction local, ServerTransaction remote) async;
  }

  class ConflictResolution {
    final TransactionSource winner; // enum: local, remote
    final String reason;
    final Map<String, dynamic>? mergedData;
  }

  enum TransactionSource { local, remote }
  ```
- **constraints**:
  - Compare timestamps: local.timestamp vs remote.timestamp
  - Newer timestamp wins (higher Unix epoch value)
  - If timestamps equal (within 1000ms), remote wins (server authoritative)
  - Conflict resolution logged to `conflict_log` table in database
- **edge_cases**:
  - Timestamps differ by > 1 year: flag as potential clock sync issue, remote wins
  - Transaction IDs match but payloads differ: this is a conflict, apply timestamp rule
  - Remote transaction deleted: if local.timestamp > remote.deletedAt, resurrect local, else keep deleted

### UpdateScheduler Service
- **type**: service
- **path**: `src/shell/lib/modules/update_scheduler.dart`
- **purpose**: Runs periodic background checks for module updates every 4 hours
- **interface**:
  ```dart
  class UpdateScheduler {
    Future<void> start() async;
    Future<void> stop() async;
    Future<DateTime?> getNextCheckTime() async;
    Future<void> checkNow() async;
    Duration get checkInterval; // 4 hours = Duration(hours: 4)
    bool get isRunning;
    Future<void> dispose() async;
  }
  ```
- **constraints**:
  - Check interval: 4 hours (14400000 milliseconds)
  - Only runs when app in foreground (paused when app backgrounded)
  - Uses dart:async Timer.periodic()
  - On each interval, calls ModuleRegistry.loadRegistry() then UpdateStateTracker.checkAllModulesForUpdates()
  - Emits UpdateEvent on UpdateStateTracker.updateEventStream if updates available
- **edge_cases**:
  - App backgrounded mid-check: cancel check, restart timer when foregrounded
  - Network offline during check: skip check, log warning, wait for next interval
  - Registry load fails: log error, do not fail app, retry on next interval
  - Update check throws exception: log error, continue timer

### UpdateTrigger Component
- **type**: component
- **path**: `src/shell/lib/modules/update_trigger.dart`
- **purpose**: Listens to network reconnect and position switch events, triggers update checks
- **interface**:
  ```dart
  class UpdateTrigger {
    Future<void> initialize(NetworkMonitor networkMonitor) async;
    Future<void> onPositionSwitch(String newPositionId) async;
    Future<void> dispose() async;
  }
  ```
- **constraints**:
  - Subscribes to NetworkMonitor.stateChanges stream
  - On NetworkState.online event (from offline), calls UpdateScheduler.checkNow()
  - On position switch event, calls UpdateScheduler.checkNow()
  - Debounces rapid triggers: minimum 60 seconds between update checks
- **edge_cases**:
  - Network flaps rapidly (online/offline/online): debounce ensures only one check triggered
  - Position switch while update check in progress: queue next check, run after current completes
  - Network offline when position switch occurs: skip update check (will check on next reconnect)

### OfflineBridgeExtension
- **type**: file
- **path**: `src/shell/lib/bridge/offline_bridge_extension.dart`
- **purpose**: Extends RuntimeHostBridge with methods for position modules to query offline status
- **interface**:
  ```dart
  extension OfflineBridgeExtension on RuntimeHostBridge {
    Future<Map<String, dynamic>> getNetworkState() async;
    // Returns: { "state": "online"|"offline"|"reconnecting", "type": "wifi"|"cellular"|"none" }

    Future<int> getPendingSyncCount() async;
    // Returns: count of transactions with syncStatus == pending

    Future<Map<String, dynamic>> forceSyncNow() async;
    // Returns: { "success": bool, "syncedCount": int, "failedCount": int, "error": string? }
  }
  ```
- **constraints**:
  - Methods callable from JavaScript via bridge.invoke("getNetworkState", {})
  - Returns JSON-serializable objects only
  - forceSyncNow() requires network online, else returns error
  - Async operations timeout after 10 seconds
- **edge_cases**:
  - Bridge called while network state transitioning: return current state even if mid-transition
  - forceSyncNow() called while auto-sync running: return existing sync result
  - getPendingSyncCount() called with database error: return -1 with error in logs

### RuntimeHostBridge Integration
- **type**: file (UPDATE existing)
- **path**: `src/shell/lib/runtime_host/runtime_host_bridge.dart`
- **purpose**: Integrate ModuleLoader into bridge, wire offline extension methods
- **interface**:
  - Add method: `Future<void> loadPositionModule(String moduleId, String? version) async`
  - This method calls ModuleLoader.loadModule() instead of old bundled approach
  - Emit events: `onModuleLoadStart`, `onModuleLoadComplete`, `onModuleLoadError`
  - Register OfflineBridgeExtension methods in method channel dispatcher
- **constraints**:
  - Backward compatible with Phase 1 bridge contract
  - No changes to authentication bridge methods
  - No changes to session brokering
  - Module load timeout: 60 seconds total (including download if needed)
- **edge_cases**:
  - Module load called while previous load in progress: queue second load, execute after first completes
  - Bridge disposed during module load: cancel load operation, cleanup resources

### Database Schema Migration
- **type**: file
- **path**: `src/shell/lib/database/offline_schema.dart`
- **purpose**: Define SQLite schema for offline transaction queue
- **interface**:
  ```sql
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
  );

  CREATE INDEX idx_sync_status ON offline_transactions(sync_status);
  CREATE INDEX idx_module_id ON offline_transactions(module_id);
  CREATE INDEX idx_timestamp ON offline_transactions(timestamp);

  CREATE TABLE IF NOT EXISTS conflict_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    transaction_id TEXT NOT NULL,
    local_timestamp INTEGER NOT NULL,
    remote_timestamp INTEGER NOT NULL,
    winner TEXT NOT NULL,
    reason TEXT NOT NULL,
    resolved_at INTEGER NOT NULL
  );

  CREATE TABLE IF NOT EXISTS sync_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    started_at INTEGER NOT NULL,
    completed_at INTEGER,
    total_transactions INTEGER NOT NULL,
    synced_count INTEGER NOT NULL,
    failed_count INTEGER NOT NULL,
    error TEXT
  );
  ```
- **constraints**:
  - Schema version stored in `PRAGMA user_version = 1`
  - Migration runs on first OfflineTransactionQueue initialization
  - Uses sqflite package (already integrated in Phase 2)
  - Database file: `offline_transactions.db`
- **edge_cases**:
  - Migration fails mid-execution: rollback transaction, throw exception
  - Database file exists but schema outdated: run migration, preserve existing data
  - Multiple isolates try to migrate simultaneously: use database-level EXCLUSIVE lock

### Performance Measurement Utility
- **type**: file
- **path**: `src/shell/lib/utils/performance_metrics.dart`
- **purpose**: Measure and log cache load performance to verify < 200ms threshold
- **interface**:
  ```dart
  class PerformanceMetrics {
    static Future<T> measure<T>(String operationName, Future<T> Function() operation) async;
    static void logMetric(String name, Duration duration);
    static Map<String, List<Duration>> getAllMetrics();
    static void clearMetrics();
  }
  ```
- **constraints**:
  - Uses Stopwatch from dart:core for measurement
  - Logs to console in debug mode: `[PERF] $operationName: ${duration.inMilliseconds}ms`
  - Stores last 100 measurements per operation in memory
  - Callable from tests to verify performance thresholds
- **edge_cases**:
  - Operation throws exception: log duration anyway, re-throw exception
  - Measurement overflow (> 1 hour): log warning, record as 3600000ms

## File Manifest

| filepath | action | description |
|----------|--------|-------------|
| `src/shell/lib/modules/module_loader.dart` | create | Cache-first module loading orchestration |
| `src/shell/lib/modules/cached_module_loader.dart` | create | Optimized cache reading for performance |
| `src/shell/lib/network/network_monitor.dart` | create | Network connectivity detection service |
| `src/shell/lib/network/network_state.dart` | create | Network state enum and models |
| `src/shell/lib/offline/offline_transaction_queue.dart` | create | SQLite-backed transaction persistence |
| `src/shell/lib/offline/sync_manager.dart` | create | Automatic sync orchestration |
| `src/shell/lib/offline/conflict_resolver.dart` | create | Last-write-wins conflict resolution |
| `src/shell/lib/modules/update_scheduler.dart` | create | Periodic 4-hour update checks |
| `src/shell/lib/modules/update_trigger.dart` | create | Reconnect/position-switch triggers |
| `src/shell/lib/bridge/offline_bridge_extension.dart` | create | Bridge methods for offline status |
| `src/shell/lib/runtime_host/runtime_host_bridge.dart` | update | Integrate ModuleLoader, wire offline extension |
| `src/shell/lib/database/offline_schema.dart` | create | SQLite schema for offline queue |
| `src/shell/lib/utils/performance_metrics.dart` | create | Performance measurement utility |
| `test/modules/module_loader_test.dart` | create | Unit tests for ModuleLoader |
| `test/network/network_monitor_test.dart` | create | Unit tests for NetworkMonitor |
| `test/offline/offline_transaction_queue_test.dart` | create | Unit tests for transaction queue |
| `test/offline/sync_manager_test.dart` | create | Unit tests for SyncManager |
| `test/offline/conflict_resolver_test.dart` | create | Unit tests for conflict resolution |
| `test/modules/update_scheduler_test.dart` | create | Unit tests for UpdateScheduler |
| `test/modules/update_trigger_test.dart` | create | Unit tests for UpdateTrigger |
| `test/bridge/offline_bridge_extension_test.dart` | create | Unit tests for bridge extensions |
| `integration_test/offline_module_load_test.dart` | create | Integration test for offline module loading |
| `integration_test/offline_data_persistence_test.dart` | create | Integration test for data persistence |
| `integration_test/network_reconnect_test.dart` | create | Integration test for reconnect sync |
| `integration_test/periodic_update_check_test.dart` | create | Integration test for 4-hour checks |
| `integration_test/cache_survival_test.dart` | create | Integration test for cache restart survival |
| `integration_test/module_download_pipeline_test.dart` | create | Integration test for download pipeline |

**Total Files**: 27 (13 implementation, 8 unit tests, 6 integration tests)

## Acceptance Criteria

### AC-3.1: Module Cache Integration Complete
**Criterion**: ModuleLoader checks ModuleCache before initiating network downloads, loads cached modules without network requests

**Test Command**: `flutter test test/modules/module_loader_test.dart --name "cache-first"`

**Pass Condition**: Exit code 0 AND test output contains "Cache checked before download" AND "Cached module loaded without network request"

**Blocking**: true

---

### AC-3.2: Cached Module Load Performance < 200ms
**Criterion**: Second load of cached module completes in under 200 milliseconds measured on Android emulator (API 34)

**Test Command**: `flutter test integration_test/offline_module_load_test.dart --name "performance" -d emulator-5554`

**Pass Condition**: Exit code 0 AND test output matches regex pattern `Cache load time: (1[0-9]{2}|[0-9]{1,2})ms` (0-199ms)

**Blocking**: true

---

### AC-3.3: Offline Module Loading Works
**Criterion**: Module loads successfully from cache when network connectivity is disabled (airplane mode simulated by mocking NetworkMonitor to return offline state)

**Test Command**: `flutter test integration_test/offline_module_load_test.dart --name "offline" -d emulator-5554`

**Pass Condition**: Exit code 0 AND test output contains "Module loaded offline" AND "No network requests made" AND "Cache hit: sample-warehouse"

**Blocking**: true

---

### AC-3.4: Cache Survives App Restart
**Criterion**: Cached modules remain accessible after app restart without re-download

**Test Command**: `flutter test integration_test/cache_survival_test.dart -d emulator-5554`

**Pass Condition**: Exit code 0 AND test output contains "Cache persisted across restart" AND "Module loaded from cache after restart"

**Blocking**: true

---

### AC-3.5: Download → Verify → Cache → Load Pipeline Works
**Criterion**: First module load downloads module, verifies signature using Phase 2 ModuleVerifier, stores in cache, then loads successfully

**Test Command**: `flutter test integration_test/module_download_pipeline_test.dart -d emulator-5554`

**Pass Condition**: Exit code 0 AND test output contains "Module downloaded" AND "Signature verified" AND "Stored in cache" AND "Module loaded"

**Blocking**: true

---

### AC-3.6: Network State Detection Works
**Criterion**: NetworkMonitor correctly detects online/offline states and emits NetworkStateChange events

**Test Command**: `flutter test test/network/network_monitor_test.dart`

**Pass Condition**: Exit code 0 AND test output contains "Online state detected" AND "Offline state detected" AND "State change event emitted"

**Blocking**: true

---

### AC-3.7: Offline Transaction Queue Persists Data
**Criterion**: OfflineTransaction objects are saved to SQLite database and survive app restart

**Test Command**: `flutter test integration_test/offline_data_persistence_test.dart --name "persistence" -d emulator-5554`

**Pass Condition**: Exit code 0 AND test output contains "Transaction queued" AND "Persisted to SQLite" AND "Survived app restart"

**Blocking**: true

---

### AC-3.8: Automatic Sync On Network Reconnect
**Criterion**: When NetworkState changes from offline to online, SyncManager.syncNow() is automatically called within 1 second

**Test Command**: `flutter test integration_test/network_reconnect_test.dart -d emulator-5554`

**Pass Condition**: Exit code 0 AND test output contains "Network reconnected" AND "Auto-sync triggered within 1000ms" AND "Transactions synced successfully"

**Blocking**: true

---

### AC-3.9: Zero Data Loss In Offline Mode
**Criterion**: User can create 50 offline transactions, all persist to SQLite, all sync successfully when network returns, zero transactions lost

**Test Command**: `flutter test integration_test/offline_data_persistence_test.dart --name "zero-loss" -d emulator-5554`

**Pass Condition**: Exit code 0 AND test output contains "50 transactions created offline" AND "50 transactions persisted" AND "50 transactions synced" AND "0 lost"

**Blocking**: true

---

### AC-3.10: Periodic Update Checks Every 4 Hours
**Criterion**: UpdateScheduler triggers ModuleRegistry.loadRegistry() and UpdateStateTracker.checkAllModulesForUpdates() every 4 hours (simulated with accelerated timer in tests)

**Test Command**: `flutter test integration_test/periodic_update_check_test.dart -d emulator-5554`

**Pass Condition**: Exit code 0 AND test output contains "Update check triggered" AND "4 hour interval verified" AND "Registry checked"

**Blocking**: true

---

### AC-3.11: Network Reconnect Triggers Update Check
**Criterion**: When NetworkState transitions to online, UpdateScheduler.checkNow() is called automatically

**Test Command**: `flutter test test/modules/update_trigger_test.dart --name "reconnect"`

**Pass Condition**: Exit code 0 AND test output contains "Network reconnected" AND "Update check triggered" AND "Registry checked for updates"

**Blocking**: true

---

### AC-3.12: Conflict Resolution Works (Last-Write-Wins)
**Criterion**: When OfflineTransaction.timestamp conflicts with ServerTransaction.timestamp, ConflictResolver selects transaction with newer timestamp

**Test Command**: `flutter test test/offline/conflict_resolver_test.dart`

**Pass Condition**: Exit code 0 AND test output contains "Conflict detected" AND "Last-write-wins applied" AND "Latest data preserved"

**Blocking**: false

---

### AC-3.13: Bridge Offline Status API Works
**Criterion**: Position modules can call bridge.invoke("getNetworkState") and bridge.invoke("getPendingSyncCount") successfully

**Test Command**: `flutter test test/bridge/offline_bridge_extension_test.dart`

**Pass Condition**: Exit code 0 AND test output contains "getNetworkState returned: {state: offline}" AND "getPendingSyncCount returned: 5"

**Blocking**: true

---

### AC-3.14: No Regression In Phase 2 Tests
**Criterion**: All 70 Phase 2 tests continue passing after Phase 3 code integration

**Test Command**: `cd src/shell && flutter test test/ && flutter test integration_test/signature_verification_test.dart integration_test/fallback_test.dart integration_test/last_known_good_test.dart integration_test/module_cache_test.dart integration_test/cached_module_load_test.dart -d emulator-5554`

**Pass Condition**: Exit code 0 AND test output contains "All tests passed!" (no test failures reported)

**Blocking**: true

---

### AC-3.15: App Launch Verification
**Criterion**: Flutter app launches successfully on Android emulator without crash, module loading UI visible within 60 seconds

**Test Command**: `cd src/shell && flutter run --release -d emulator-5554 & sleep 60 && adb -s emulator-5554 shell dumpsys activity activities | grep mResumedActivity`

**Pass Condition**: Exit code 0 AND output contains "com.foundry.position_shell/.MainActivity" (app package in resumed state)

**Blocking**: true

**Environment**: Android API 34 emulator (Pixel 6 Pro system image), Flutter SDK 3.16.0 or higher

## Dependencies

### Required Flutter/Dart Packages

- **name**: connectivity_plus
  **version**: ^5.0.0
  **install_command**: `flutter pub add connectivity_plus:^5.0.0`
  **purpose**: Network state monitoring and connectivity detection

- **name**: sqflite
  **version**: ^2.3.0
  **install_command**: (already installed in Phase 2, no action needed)
  **purpose**: SQLite database for offline transaction queue

- **name**: path_provider
  **version**: ^2.1.0
  **install_command**: (already installed in Phase 2, no action needed)
  **purpose**: App support directory path for database and cache files

- **name**: http
  **version**: ^1.1.0
  **install_command**: (already installed in Phase 2, no action needed)
  **purpose**: HTTP client for downloading modules and sync API calls

- **name**: uuid
  **version**: ^4.0.0
  **install_command**: `flutter pub add uuid:^4.0.0`
  **purpose**: Generate transaction IDs for OfflineTransaction

- **name**: fake_async
  **version**: ^1.3.1
  **install_command**: `flutter pub add dev:fake_async:^1.3.1`
  **purpose**: Testing time-based operations (UpdateScheduler tests)

### Phase 2 Service Dependencies

- ModuleCache (integrate into module loading flow)
- ModuleRegistry (add periodic check calls)
- FallbackManager (unchanged, continue using)
- ModuleVerifier (unchanged, continue using)
- UpdateStateTracker (add trigger mechanisms)
- ModuleDownloader (unchanged, continue using)

## Out Of Scope

What Builder must NOT build in this phase:

- **Biometric authentication**: deferred to Phase 4 (High-Trust Workflows)
- **Role switching security**: deferred to Phase 4
- **Camera/barcode scanning**: deferred to Phase 4 (Rich Device Workflow)
- **Photo capture and attachment**: deferred to Phase 4
- **Bluetooth scanner integration**: deferred to Phase 4
- **Bluetooth printing**: deferred to Phase 4
- **NFC tag reading**: deferred to Phase 4
- **Push notification handling**: deferred to Phase 4
- **Background data refresh**: deferred to Phase 4
- **Performance profiling infrastructure**: deferred to Phase 5
- **App store policy validation**: deferred to Phase 5
- **Production CDN infrastructure**: always use mock URLs
- **Complex conflict resolution beyond last-write-wins**: last-write-wins is sufficient for POC
- **Multi-user offline collaboration**: single-user offline mode only
- **Delta sync optimization**: full transaction sync only
- **Offline module updates**: module downloads require online connectivity
- **Intelligent network type detection for downloads**: WiFi/cellular distinction is optional
- **Background sync while app suspended**: sync only when app in foreground
- **Encrypted database**: SQLite database not encrypted (acceptable for POC)

## Phase Boundaries

### Receives From Previous Phase

From Phase 2 (Trust & Delivery):

```dart
class ModuleCache {
  Future<String?> getCachedModulePath(String moduleId, String version);
  Future<List<String>> listCachedVersions(String moduleId);
  Future<int> getCacheSize();
  Future<String> getCacheDirectory();
  Future<void> runGarbageCollection();
  Future<void> storeModule(String moduleId, String version, String sourcePath);
}

class ModuleRegistry {
  Future<String?> getInstalledVersion(String moduleId);
  Future<List<ModuleMetadata>> getAvailableModules();
  Future<List<String>> getCachedVersions(String moduleId);
  bool get isRegistryLoaded;
  Future<void> loadRegistry(String manifestUrl);
}

class FallbackManager {
  Future<String?> getLastKnownGoodVersion(String moduleId);
  Future<int> getFailureCount(String moduleId, String version);
  Future<bool> isBlocked(String moduleId, String version);
  Future<void> recordLoadFailure(String moduleId, String version, String error);
  Future<void> markAsLastKnownGood(String moduleId, String version);
  Future<void> resetFailures(String moduleId, String version);
}

class ModuleVerifier {
  Future<VerificationResult> verifyModule(String modulePath, ModuleMetadata metadata);
  Future<bool> verifySignature(File signatureFile, File moduleFile);
}

class UpdateStateTracker {
  UpdateState getUpdateState(String moduleId);
  Future<Map<String, UpdateCheckResult>> checkAllModulesForUpdates();
  Stream<UpdateEvent> get updateEventStream;
  Future<void> installModuleUpdate(String moduleId, String version);
}

class ModuleDownloader {
  Future<String> download(String url, String moduleId, String version);
  Future<void> cancelDownload(String moduleId);
  Stream<DownloadProgress> getProgressStream(String moduleId);
}
```

### Provides To Next Phase

To Phase 4 (High-Trust & Native Capabilities):

```dart
class ModuleLoader {
  Future<LoadResult> loadModule(String moduleId, {String? version});
  Future<void> unloadModule(String moduleId);
  Future<bool> isModuleCached(String moduleId, String version);
  Future<Duration> getLastLoadTime(String moduleId);
  Stream<ModuleLoadEvent> get loadEventStream;
}

class NetworkMonitor {
  NetworkState get currentState;
  Stream<NetworkState> get stateChanges;
  Future<bool> isOnline();
  Future<NetworkType> getNetworkType();
}

class OfflineTransactionQueue {
  Future<void> enqueue(OfflineTransaction transaction);
  Future<List<OfflineTransaction>> getPendingTransactions();
  Future<int> getPendingCount();
  Future<void> markSynced(String transactionId);
  Stream<SyncEvent> get syncEventStream;
}

class SyncManager {
  Future<SyncResult> syncNow();
  Future<bool> isSyncing();
  Future<DateTime?> getLastSyncTime();
  Future<void> pauseAutoSync();
  Future<void> resumeAutoSync();
  Stream<SyncProgress> get syncProgressStream;
}

class UpdateScheduler {
  Future<void> start();
  Future<void> stop();
  Future<DateTime?> getNextCheckTime();
  Future<void> checkNow();
  Duration get checkInterval; // 4 hours
}
```

## Environment Requirements

- **Flutter SDK**: 3.16.0 or higher
- **Dart SDK**: 3.2.0 or higher (bundled with Flutter)
- **Java JDK**: 17 or higher (for Android builds)
- **Gradle**: 7.5 or higher (configured in android/gradle-wrapper.properties)
- **Android SDK**: API 21 minimum, API 34 target
- **Android Emulator**: Pixel 6 Pro system image (API 34) recommended for testing
- **SQLite**: version 3.x (provided by sqflite package)
- **Network**: Internet connectivity required for module downloads (offline mode requires prior cache)

## Manual Test Steps

### Test 1: Offline Module Loading (Scenario W-4)
1. Launch app with network enabled, login with mock credentials
2. Load warehouse-clerk module (first load triggers download)
3. Verify logs show "Module downloaded", "Signature verified", "Stored in cache"
4. Close app completely (swipe away from recents)
5. Enable airplane mode on emulator: `adb shell cmd connectivity airplane-mode enable`
6. Launch app
7. **Expected**: App opens, module loads from cache, logs show "Cache hit: sample-warehouse v1.0.0", "Load time: <200ms"
8. Navigate through module UI
9. **Expected**: Module UI renders correctly, no network errors

### Test 2: Offline Transaction Persistence (Scenario W-3)
1. Launch app in airplane mode
2. Navigate to warehouse receiving workflow
3. Create 50 line items (scan barcodes, enter quantities)
4. Submit transaction
5. **Expected**: UI shows "Queued for sync" notification
6. Check pending sync count via bridge (call getPendingSyncCount from devtools console)
7. **Expected**: Returns 1
8. Close app, relaunch in airplane mode
9. **Expected**: Transaction still visible in pending queue
10. Disable airplane mode: `adb shell cmd connectivity airplane-mode disable`
11. Wait 5 seconds
12. **Expected**: UI shows "Sync in progress", then "Sync complete"
13. Check pending count
14. **Expected**: Returns 0
15. Check server logs (mock endpoint)
16. **Expected**: Transaction present with all 50 line items

### Test 3: Network Reconnect Auto-Sync
1. Create 10 transactions in airplane mode
2. Verify pending sync count: 10
3. Disable airplane mode
4. **Expected**: Within 1 second, sync starts automatically (progress indicator shown)
5. Wait for completion
6. **Expected**: All 10 transactions sync successfully, pending count returns to 0
7. Check logs
8. **Expected**: "Network state changed: offline → online", "Auto-sync triggered", "Synced 10 transactions in 2.3s"

### Test 4: Periodic Update Check (Scenario W-5)
1. Launch app
2. Note current time
3. Inject accelerated timer for testing: use fake_async to simulate 4 hours passing in 5 seconds
4. Wait 5 seconds
5. Check logs
6. **Expected**: "Periodic update check triggered", "Registry checked", "No updates available"
7. Modify registry on mock server to include updated module version
8. Wait another 5 seconds (simulated 4 hours)
9. **Expected**: "Update available: warehouse-clerk v1.1.0", notification shown in UI

### Test 5: Cache Performance Measurement (Scenario W-5)
1. Clear app data: `adb shell pm clear com.foundry.position_shell`
2. Launch app
3. Load module (first time)
4. Check logs for load time
5. **Expected**: "Module load time: <download_time>ms" (will be > 1000ms)
6. Close app, relaunch
7. Load module (second time, from cache)
8. Check logs
9. **Expected**: "Module load time: <cache_time>ms", `<cache_time>` is less than 200
10. Verify no network request made (check adb logcat for HTTP requests)
11. **Expected**: No HTTP GET requests to module CDN

## Phase Achievement

When Phase 3 passes, the user can perform complete warehouse receiving workflows entirely offline with zero data loss, modules load from cache in under 200 milliseconds, and all offline operations sync automatically when connectivity returns.

## Validation Notes

### Ambiguities Resolved

- **"fast cache load" (plan.md line 12)** → "under 200 milliseconds measured with Stopwatch from dart:core"
- **"automatic sync" (plan.md line 23)** → "SyncManager.syncNow() called within 1 second of NetworkState change to online"
- **"periodic checks" (plan.md line 45)** → "Timer.periodic() with Duration(hours: 4), only when app in foreground"
- **"zero data loss" (plan.md REQ-OFFLINE-3)** → "All OfflineTransaction records persist to SQLite, verified by test creating 50 transactions and confirming 50 synced"

### Assumptions Made

- **Conflict resolution strategy**: Last-write-wins is sufficient for POC scope. Transaction with newer timestamp (higher Unix epoch milliseconds) wins. If timestamps within 1000ms of each other, server version (remote) wins as authoritative source.

- **Sync timing on reconnect**: Immediate auto-sync within 1 second is better UX than waiting for user action. Implementing immediate trigger. If this causes issues (e.g., rapid network flapping), can add debounce in future iterations.

- **50-line transaction structure**: Scenario W-3 mentions "50-line receiving transaction" but doesn't define schema. Assuming structure:
  ```json
  {
    "transactionId": "uuid",
    "type": "receiving",
    "items": [
      {"sku": "string", "quantity": number, "location": "string"},
      ...49 more items
    ],
    "timestamp": 1710604800000,
    "userId": "string"
  }
  ```
  This is a reasonable warehouse receiving transaction model. Builder will implement this schema for OfflineTransaction.payload.

- **Transaction queue size limit**: 1000 transactions is a reasonable maximum for mobile device storage and sync performance. Calculated assuming average transaction payload size of 5KB: 1000 * 5KB = 5MB total queue storage, acceptable for mobile devices.

- **Network heartbeat**: Implementing 30-second ping to 1.1.1.1 to verify internet reachability beyond just connectivity package's "connected to WiFi" signal. This catches scenarios like captive portals or VPN issues.

### Q&A References

None. All UNCLEAR items from plan.md resolved through reasonable assumptions documented above.

### Drift Corrections

Not applicable (Cycle 1 - no baseline to compare against).
