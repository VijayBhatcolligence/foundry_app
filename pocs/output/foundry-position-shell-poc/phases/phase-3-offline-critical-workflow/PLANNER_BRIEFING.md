# PLANNER BRIEFING: Phase 3 — Offline-Critical Workflow

**Phase ID**: `phase-3-offline-critical-workflow`
**Agent**: PLANNER
**Agent Doc Version**: 6.1.0
**Model**: claude-sonnet-4-6-20250514
**Timestamp**: 2026-03-16T15:00:00Z

---

## Mission Statement

Create a comprehensive plan for Phase 3 that enables complete offline warehouse workflows with zero data loss and automatic sync on reconnection. This phase MUST complete the cache integration from Phase 2 (ADR-001) and deliver production-ready offline capabilities.

---

## Phase 3 Achievement Goal

> User can perform complete warehouse pick-pack workflows entirely offline, with zero data loss, and automatic sync when connectivity returns.

**Key Quantitative Thresholds**:
- Cached module load: `< 200ms` (measured on device)
- Offline persistence: Zero data loss
- Sync on reconnect: Automatic (no user intervention)
- Network detection: Immediate (< 1 second)

---

## Dependencies From Phase 2 (COMPLETE ✅)

Phase 2 delivered the following **verified and tested** interfaces:

### 1. ModuleCache Service
**Location**: `src/shell/lib/modules/module_cache.dart`
**Status**: Service built and tested ✅, **NOT integrated into module loading** ❌

**Methods Available**:
```dart
Future<String?> getCachedModulePath(String moduleId, String version)
Future<List<String>> listCachedVersions(String moduleId)
Future<int> getCacheSize()
Future<String> getCacheDirectory()
Future<void> runGarbageCollection()
```

**CRITICAL**: Phase 3 MUST integrate this into actual module loading flow (ADR-001).

### 2. ModuleRegistry Service
**Location**: `src/shell/lib/modules/module_registry.dart`
**Status**: Complete ✅

**Methods Available**:
```dart
Future<String?> getInstalledVersion(String moduleId)
Future<List<ModuleMetadata>> getAvailableModules()
Future<List<String>> getCachedVersions(String moduleId)
bool get isRegistryLoaded
Future<void> loadRegistry(String manifestUrl)
```

### 3. FallbackManager Service
**Location**: `src/shell/lib/modules/fallback_manager.dart`
**Status**: Complete ✅, uses SQLite for persistence

**Methods Available**:
```dart
Future<String?> getLastKnownGoodVersion(String moduleId)
Future<int> getFailureCount(String moduleId, String version)
Future<bool> isBlocked(String moduleId, String version)
Future<void> recordLoadFailure(String moduleId, String version, String error)
Future<void> markAsLastKnownGood(String moduleId, String version)
```

**Database**: SQLite (`sqflite` package already integrated)

### 4. ModuleVerifier Service
**Location**: `src/shell/lib/security/module_verifier.dart`
**Status**: Complete ✅ (RSA-2048 signature verification working, 133ms performance)

**Methods Available**:
```dart
Future<VerificationResult> verifyModule(String modulePath, ModuleMetadata metadata)
Future<bool> verifySignature(File signatureFile, File moduleFile)
```

### 5. UpdateStateTracker
**Location**: `src/shell/lib/modules/module_updater.dart`
**Status**: Complete ✅, **periodic checks NOT implemented** ❌

**Methods Available**:
```dart
UpdateState getUpdateState(String moduleId)
Future<Map<String, UpdateCheckResult>> checkAllModulesForUpdates()
Stream<UpdateEvent> get updateEventStream
Future<void> installModuleUpdate(String moduleId, String version)
```

**CRITICAL**: Phase 3 MUST add periodic registry checks (every 4 hours) and network reconnect handling.

---

## Phase 2 Incomplete Items (Phase 3 MUST Complete)

### 1. Cache Integration (ADR-001)
**Status**: Service exists but NOT integrated into module loading

**What Phase 3 Must Do**:
- ✅ Wire `ModuleCache` into WebView module loading flow
- ✅ Implement: download → verify → cache → load pipeline
- ✅ Implement: cache lookup on second load (< 200ms)
- ✅ Test offline loading (network disabled, module loads from cache)
- ✅ Measure and verify < 200ms threshold on device

**Reference**: `phases/phase-2-trust-delivery/ADR-001-cache-integration-completion.md`

### 2. Periodic Registry Checks
**Status**: Registry checks only on app startup, no periodic/reconnect checks

**What Phase 3 Must Do**:
- ✅ Add periodic background checks (every 4 hours)
- ✅ Add network reconnect detection
- ✅ Trigger registry check on network return
- ✅ Add position switch triggers (check on role change)

**Reference**: `phases/phase-2-trust-delivery/planner/plan.md` line 345

---

## Key Scenarios For Phase 3

**Reference**: `pocs/foundry-position-shell-poc-scenarios.md`

### Scenario W-3: Full Offline Receiving Transaction
**What It Proves**: Local persistence, transaction queue, sync on reconnect

**Success Criteria**:
- Complete a 50-line receiving transaction with zero connectivity
- All data persisted locally
- Sync executes automatically on reconnect with no data loss

### Scenario W-4: Offline-First Launch
**What It Proves**: App and position module available without network

**Success Criteria**:
- Device in airplane mode, app opens
- Module loads from cache
- Previous data visible
- New transactions queue locally

### Scenario W-5: Asset/Page Caching
**What It Proves**: Shell caches position module bundles and static assets locally

**Success Criteria**:
- Second load of position module `< 200ms` from local cache
- No network request for cached assets
- Cache survives app restart

### Scenario X-11: Bad Module Update Rollback
**What It Proves**: Failed or incompatible updates do not strand the user

**Success Criteria**:
- Incompatible or tampered module is rejected
- Last-known-good module remains available from cache without reinstall

---

## Technical Architecture Context

**Stack**:
- Flutter/Dart shell (native app)
- WebView runtime host (JavaScript environment)
- React position modules (business logic)
- SQLite persistence (`sqflite` package integrated)
- Platform channels for native features

**Trust Boundary**:
- Shell owns auth tokens (NO leakage to modules)
- Modules receive scoped sessions only
- Bridge provides typed capabilities (not generic proxy)
- CSP enforcement on WebView

**Module Loading Flow** (Phase 1):
```
Shell → RuntimeHost (WebView) → Module (React)
```

**Current Module Loading** (Phase 1 bundled approach):
```dart
// In runtime host WebView:
await loadModuleFromBundle('warehouse-clerk-v1.0.0.js');
```

**Phase 3 MUST Change To**:
```dart
// First load:
final cachedPath = await moduleCache.getCachedModulePath(moduleId, version);
if (cachedPath != null) {
  await loadModuleFromCache(cachedPath); // < 200ms
} else {
  final downloadedPath = await moduleDownloader.download(/*...*/);
  await moduleVerifier.verify(downloadedPath);
  await moduleCache.storeModule(moduleId, version, downloadedPath);
  await loadModuleFromCache(cachedPath);
}
```

---

## What Phase 3 MUST Build

### 1. Complete Cache Integration
- Wire `ModuleCache` into WebView module loading
- Implement download → verify → cache → load pipeline
- Implement cache lookup before network requests
- Measure < 200ms threshold on device
- Test offline loading (airplane mode)

### 2. Offline Data Persistence
- Local database for offline operations (SQLite already available)
- Queue for pending sync operations
- Conflict resolution strategy (last-write-wins for POC)
- Data integrity guarantees (atomic transactions)

### 3. Network State Management
- Detect network availability (connectivity_plus package recommended)
- Handle online ↔ offline transitions
- Trigger registry checks on reconnect
- Auto-sync queued operations when online returns

### 4. Periodic Update Checks
- Background registry checks (every 4 hours)
- Update notifications (use existing UpdateStateTracker)
- Automatic download when on WiFi (optional optimization)

### 5. Integration Tests
- Offline module loading test (airplane mode)
- Data persistence test (create offline, sync online)
- Network reconnect test (offline → online transition)
- Cached load performance test (< 200ms measurement)
- Registry periodic check test (time-based trigger)

---

## What Phase 3 MUST NOT Include

These are Phase 4+ scope:
- ❌ Biometric authentication (Phase 4)
- ❌ Role switching security (Phase 4)
- ❌ Camera/barcode scanning (Phase 4)
- ❌ Performance profiling tools (Phase 5)
- ❌ Store policy validation (Phase 5)

---

## Critical Constraints

### From Phase 2 Learnings:

1. **Integration is Mandatory**
   - Phase 2 built services but didn't integrate → user couldn't test features
   - Phase 3 MUST integrate features into running app
   - User should be able to manually test offline mode after Phase 3

2. **Cache Integration is Essential**
   - ADR-001 explicitly says: complete in Phase 3
   - Required for offline module loading
   - Performance threshold: < 200ms

3. **Don't Touch Working Features**
   - Signature verification is complete and tested (133ms)
   - FallbackManager is complete and tested
   - Don't refactor working Phase 2 code

### Technical Stack Constraints:
- Must use Flutter/Dart for shell
- Must use existing SQLite integration (sqflite)
- Must preserve Phase 1 trust boundary (no token leakage)
- Must preserve Phase 2 signature verification

---

## Success Criteria For Phase 3

**Must Pass**:
1. ✅ Module loads from cache in < 200ms (measured on device)
2. ✅ Module loads offline (network disabled, no errors)
3. ✅ Data persists offline (user actions saved to SQLite)
4. ✅ Sync works on reconnect (offline data uploaded automatically)
5. ✅ Periodic registry checks work (every 4 hours)
6. ✅ Cache integration complete (ADR-001 resolved)
7. ✅ All Phase 2 tests still pass (no regressions)
8. ✅ Phase 3 integration tests pass

**Deliverables**:
- `phases/phase-3-offline-critical-workflow/planner/plan.md` ← YOU WRITE THIS
- Working code in `src/shell/lib/`
- Integration tests in `integration_test/`
- Updated documentation

---

## Reference Documents

**CRITICAL - READ THESE**:
1. `pocs/foundry-position-shell-parity-evaluation.md` - Architecture requirements (Section 6B: Slice 3)
2. `pocs/foundry-position-shell-poc-scenarios.md` - Test scenarios (W-3, W-4, W-5, X-11)
3. `phases/phase-2-trust-delivery/FINAL_SUMMARY.md` - Phase 2 deliverables and interfaces
4. `phases/phase-2-trust-delivery/ADR-001-cache-integration-completion.md` - Cache integration decision

**Available in Repo**:
- `C:\Users\bijay\OneDrive\Desktop\auto_agent3\pocs\foundry-position-shell-parity-evaluation.md`
- `C:\Users\bijay\OneDrive\Desktop\auto_agent3\pocs\foundry-position-shell-poc-scenarios.md`
- `C:\Users\bijay\OneDrive\Desktop\auto_agent3\pocs\output\foundry-position-shell-poc\phases\phase-2-trust-delivery\FINAL_SUMMARY.md`

---

## PLANNER Instructions

**Your Job**:
1. Read the reference documents listed above
2. Create `phases/phase-3-offline-critical-workflow/planner/plan.md`
3. Follow the schema from `.claude/agents/planner/SCHEMA.md`
4. Focus on integration (not just infrastructure)
5. Ensure < 200ms cache load is measurable
6. Include offline testing in acceptance criteria

**Critical Requirements**:
- Complete ADR-001 cache integration
- Add periodic registry checks
- Build offline data persistence
- Implement network state management
- All features must be INTEGRATED and user-testable

**Remember**:
- You are ONLY planning, not building
- Write one plan.md for Phase 3
- Define clear acceptance criteria (testable)
- Specify integration points with Phase 2 services
- Include performance measurement acceptance criteria

---

## Schema Compliance

Your `plan.md` MUST include:
- PHASE_ID: phase-3-offline-critical-workflow
- DEPENDS_ON: phase-2-trust-delivery
- PROVIDES_TO: phase-4-high-trust-native-capabilities
- ACHIEVEMENT: [user-facing goal]
- WHAT_TO_BUILD: [detailed implementation plan]
- ACCEPTANCE_CRITERIA: [12-15 testable ACs]
- OUT_OF_SCOPE: [explicit boundaries]
- INTERFACES: [inputs from Phase 2, outputs to Phase 4]

---

## Launch Verification

Phase 3 involves app features, so launch verification is ENABLED:
- Target device: Android emulator (preferred) or Windows
- Timeout: 60 seconds
- Tester will verify app launches and offline mode works

---

## Token Budget

**Phase Budget**: 20,000 tokens (from config.yaml)
**Model**: claude-sonnet-4-6-20250514
**Your Allocation**: ~10,000 tokens for planning

---

**PLANNER: BEGIN PHASE 3 PLANNING NOW**

Write `phases/phase-3-offline-critical-workflow/planner/plan.md` according to your ROLE.md and SCHEMA.md.
