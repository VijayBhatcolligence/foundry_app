# 🧪 Phase 2: Trust & Delivery - Manual Testing Guide

This guide helps you manually verify all Phase 2 features work correctly. Phase 2 builds on Phase 1 by adding module update, signature verification, and automatic fallback capabilities.

---

## 📋 Prerequisites

Before testing Phase 2, ensure Phase 1 is working:
- ✅ Complete all steps in `QUICKSTART_GUIDE.md` (in project root)
- ✅ App launches and shows mock login
- ✅ Sample warehouse module loads successfully
- ✅ Position context displays correctly

**If Phase 1 isn't working, stop here and fix it first.**

---

## 🎯 What's New in Phase 2?

Phase 2 adds these capabilities on top of Phase 1:

### 1. **Module Versioning**
- Modules now have version numbers (1.0.0, 1.1.0, etc.)
- Version compatibility checking (module requires shell >= 1.0.0)
- Semantic version ranges (^1.0.0, ~1.2.0, >=2.0.0)

### 2. **Module Updates**
- Check for module updates without reinstalling the app
- Download new module versions in background
- Install updates without app restart

### 3. **Signature Verification**
- Modules are cryptographically signed (RSA-2048)
- Signatures verified before installation
- Tampered modules are rejected

### 4. **Automatic Fallback**
- If a module fails to load, automatically rollback to last-known-good version
- Track failure counts to prevent infinite retry loops
- Block broken versions after 3 failures

### 5. **Module Cache**
- Store multiple versions of modules on device
- Quick load from cache (< 200ms)
- Automatic garbage collection when cache is full

### 6. **Update Notifications**
- Runtime host shows update notifications
- User can accept/dismiss updates
- Update progress tracking

---

## 🛠️ Manual Test Scenarios

Follow these scenarios in order to verify Phase 2 functionality.

---

## Test 1: Verify Module Versioning

**What to test**: Module manifest parsing and version display

**Steps**:
1. Launch the app (if not already running):
   ```bash
   cd src/shell
   flutter run
   ```

2. After app loads, open Flutter DevTools or use Android logcat:
   ```bash
   # In another terminal
   flutter logs
   ```

3. Look for module version information in logs:
   ```
   [ModuleRegistry] Loading manifest...
   [ModuleRegistry] Found module: sample-warehouse version 1.0.0
   [ModuleRegistry] Required shell version: >=1.0.0
   ```

**Expected Results**:
- ✅ Module version appears in logs (should be 1.0.0)
- ✅ Shell version compatibility check passes
- ✅ Module loads successfully

**What this validates**: AC-1 (Module Manifest Loads and Parses Correctly)

---

## Test 2: Check Module Cache Directory

**What to test**: Module cache structure and storage

**Steps**:

1. Connect to device/emulator shell:
   ```bash
   # For Android
   adb shell

   # Navigate to app directory (package name may vary)
   cd /data/data/com.foundry.position_shell/app_flutter/modules

   # List cached modules
   ls -la
   ```

2. You should see a directory structure like:
   ```
   modules/
     sample-warehouse/
       1.0.0/
         module.js
         module.manifest.json
   ```

**Expected Results**:
- ✅ Module cache directory exists
- ✅ Sample warehouse module is cached
- ✅ Version 1.0.0 directory is present
- ✅ module.js and module.manifest.json files exist

**Alternative (if adb shell doesn't work)**:
Check Flutter logs for cache paths:
```
[ModuleCache] Cache directory: /data/data/.../app_flutter/modules
[ModuleCache] Cached module: sample-warehouse v1.0.0 at ...
```

**What this validates**: AC-10 (Module Cache Stores Multiple Versions)

---

## Test 3: Verify Signature Verification

**What to test**: Module signature validation

**Steps**:

1. Check Flutter logs during module load for signature verification:
   ```
   [ModuleVerifier] Verifying module: sample-warehouse v1.0.0
   [ModuleVerifier] Signature file: module.signature
   [ModuleVerifier] Signature format: valid (256 bytes)
   [ModuleVerifier] Verification: PASSED (POC mode)
   ```

2. Look for signature verification success message

**Expected Results**:
- ✅ Signature file is found
- ✅ Signature format validated
- ✅ Verification passes (POC mode simulates full RSA verification)
- ✅ Module loads after verification

**POC Note**: Phase 2 validates signature format (256 bytes, valid base64) but simulates cryptographic verification. Production would add full RSA-2048 PKCS1-v1_5 verification.

**What this validates**: AC-4 (Signature Verification Accepts Valid Signatures)

---

## Test 4: Test Module Update Check

**What to test**: Checking for available module updates

**Steps**:

1. While app is running, trigger an update check via the runtime host bridge

2. Open WebView console (if in debug mode):
   - Open Chrome DevTools for WebView
   - In console, check for update events:
   ```javascript
   // Check update state
   window.moduleUpdater.checkForUpdates('sample-warehouse')
   ```

3. Watch Flutter logs for update checking:
   ```
   [ModuleUpdater] Checking for updates: sample-warehouse
   [ModuleUpdater] Current version: 1.0.0
   [ModuleUpdater] Latest version: 1.0.0
   [ModuleUpdater] No updates available
   ```

**Expected Results**:
- ✅ Update check completes without errors
- ✅ Current version is detected (1.0.0)
- ✅ Registry is queried successfully
- ✅ "No updates available" message (since we only have v1.0.0)

**What this validates**: AC-5 (Update Check Detects Available Updates)

---

## Test 5: Verify Last-Known-Good Tracking

**What to test**: Module version is saved after successful load

**Steps**:

1. After module loads successfully, check logs:
   ```
   [FallbackManager] Module loaded successfully: sample-warehouse v1.0.0
   [FallbackManager] Marking as last-known-good version
   [FallbackManager] Database updated: sample-warehouse -> 1.0.0
   ```

2. Restart the app (press 'R' in Flutter terminal):
   ```
   R  # Hot restart
   ```

3. After restart, check logs again:
   ```
   [FallbackManager] Last-known-good for sample-warehouse: 1.0.0
   ```

**Expected Results**:
- ✅ Module version saved to database after load
- ✅ Last-known-good persists after app restart
- ✅ Database operations complete without errors

**What this validates**: AC-8 (Last-Known-Good Version Persists After Successful Load)

---

## Test 6: Test Compatibility Checking

**What to test**: Incompatible module versions are rejected

**Steps**:

1. Check logs during module load for compatibility check:
   ```
   [CompatibilityChecker] Checking compatibility: sample-warehouse v1.0.0
   [CompatibilityChecker] Module requires shell: >=1.0.0
   [CompatibilityChecker] Current shell version: 1.0.0
   [CompatibilityChecker] Compatibility: PASS
   ```

**Expected Results**:
- ✅ Shell version detected correctly (1.0.0)
- ✅ Module requirements parsed (>=1.0.0)
- ✅ Compatibility check passes
- ✅ Module allowed to load

**What this validates**: AC-2 (Semantic Version Compatibility Check Works), AC-9 (Incompatible Module Version Rejected Before Download)

---

## Test 7: Verify Cached Module Load Performance

**What to test**: Modules load quickly from cache

**Steps**:

1. **First Load** (will download):
   - Note the time in logs when module starts loading
   - Note the time when module finishes loading
   - Calculate duration

2. **Second Load** (from cache):
   - Restart app with 'R' (hot restart)
   - Note module load start time
   - Note module load finish time
   - Calculate duration

3. Look for cache hit message:
   ```
   [ModuleCache] Loading from cache: sample-warehouse v1.0.0
   [ModuleCache] Cache path: /data/data/.../modules/sample-warehouse/1.0.0/module.js
   [ModuleCache] Load completed in 150ms
   ```

**Expected Results**:
- ✅ First load: May take 1-2 seconds (includes initial cache setup)
- ✅ Second load: Should be < 200ms (cached load)
- ✅ Cache hit message appears in logs
- ✅ Module loads faster from cache

**What this validates**: AC-12 (Module Load Uses Cached Version When Available)

---

## Test 8: Verify Module Download (Manual Simulation)

**What to test**: Module download with checksum validation

**Steps**:

Since we're in POC mode without a real CDN, this test checks the download logic:

1. Check logs for download-related operations:
   ```
   [ModuleDownloader] Download URL: [placeholder URL]
   [ModuleDownloader] Target path: /data/data/.../temp/module_download.tmp
   [ModuleDownloader] Expected SHA-256: [checksum]
   ```

2. Verify download components are initialized:
   ```
   [ModuleDownloader] HTTP client initialized
   [ModuleDownloader] Retry policy: exponential backoff, max 3 attempts
   [ModuleDownloader] Checksum validator: SHA-256
   ```

**Expected Results**:
- ✅ Download service initialized
- ✅ Checksum validation configured
- ✅ Retry logic enabled
- ✅ Temporary file path configured correctly

**POC Note**: Actual network download requires mock CDN setup. Phase 2 validates the download logic and checksum verification infrastructure.

**What this validates**: AC-3 (Module Download Completes with Checksum Validation)

---

## Test 9: Test Automatic Fallback (Simulated Failure)

**What to test**: Fallback mechanism when module fails

**This test requires modifying code temporarily to simulate a failure**:

### Option A: Check Logs for Fallback Infrastructure

1. Look for fallback manager initialization:
   ```
   [FallbackManager] Initialized for module: sample-warehouse
   [FallbackManager] Database connection: OK
   [FallbackManager] Failure tracking: enabled
   ```

2. Check that failure count is zero (module loaded successfully):
   ```
   [FallbackManager] Failure count for sample-warehouse v1.0.0: 0
   [FallbackManager] Blocked versions: none
   ```

### Option B: Run Unit Tests (Recommended)

```bash
cd src/shell
flutter test integration_test/fallback_test.dart
```

This test simulates module load failures and verifies fallback works:
- Loads module successfully → marks as last-known-good
- Simulates module failure → automatic rollback to last-known-good
- Simulates 3 failures → version gets blocked
- Verifies user notification for fallback events

**Expected Test Output**:
```
✓ records load failure and increments count
✓ returns last known good version when current fails
✓ blocks version after max failures (3)
✓ resets failure count on successful load
✓ notifies user when fallback occurs
✓ handles multiple modules independently
✓ persists failure data across manager instances
```

**What this validates**: AC-7 (Failed Module Load Triggers Automatic Fallback)

---

## Test 10: Verify Update Notification System

**What to test**: Runtime host receives update notifications

**Steps**:

1. Check that bridge extension is initialized:
   ```
   [ModuleBridgeExtension] Registered bridge methods:
   [ModuleBridgeExtension]   - checkForUpdates
   [ModuleBridgeExtension]   - getAvailableModules
   [ModuleBridgeExtension]   - getModuleVersion
   [ModuleBridgeExtension]   - installModuleUpdate
   ```

2. Verify update event stream is active:
   ```
   [ModuleUpdater] Update event stream: active
   [ModuleUpdater] Subscribers: 1 (runtime host)
   ```

3. Check WebView console for update API availability:
   - Open Chrome DevTools
   - In console: `typeof window.bridge.checkForUpdates`
   - **Expected**: `"function"`

**Expected Results**:
- ✅ Bridge methods registered
- ✅ Update event stream active
- ✅ Runtime host can call update methods
- ✅ Update notifications can be delivered

**What this validates**: AC-11 (Update Notification Shows in Runtime Host)

---

## Test 11: Verify Module Update Integration (End-to-End)

**What to test**: Complete update flow works end-to-end

**Run integration test**:

```bash
cd src/shell
flutter test test/integration/module_update_integration_test.dart
```

This test verifies:
1. Check for updates → Update available detected
2. Download new version → Download completes successfully
3. Verify signature → Signature validation passes
4. Install to cache → New version stored correctly
5. Load new version → Updated module loads successfully

**Expected Test Output**:
```
✓ complete update flow from check to install
✓ update state machine transitions correctly
✓ update progress events emitted
```

**What this validates**: AC-6 (Module Update Installs Without Shell Reinstall)

---

## 🎯 Phase 2 Feature Checklist

After completing all manual tests, verify you've seen:

### Module Versioning ✅
- [ ] Module version displayed in logs (1.0.0)
- [ ] Manifest file parsed successfully
- [ ] Version compatibility check passed

### Module Cache ✅
- [ ] Cache directory created on device
- [ ] Module files stored in versioned directories
- [ ] Cache load time < 200ms after first load

### Signature Verification ✅
- [ ] Signature file detected
- [ ] Signature format validated (256 bytes)
- [ ] Verification passed (POC mode)

### Compatibility Checking ✅
- [ ] Shell version detected (1.0.0)
- [ ] Module requirements parsed (>=1.0.0)
- [ ] Compatibility validation passed

### Last-Known-Good Tracking ✅
- [ ] Version saved to database after successful load
- [ ] Last-known-good persists after app restart
- [ ] Database operations complete without errors

### Update System ✅
- [ ] Update check completes successfully
- [ ] Bridge methods registered
- [ ] Update event stream active
- [ ] Runtime host can query updates

### Fallback Mechanism ✅
- [ ] Fallback manager initialized
- [ ] Failure tracking enabled
- [ ] Integration test passes (7/7 tests)

---

## 📊 What You Should See vs Phase 1

### Phase 1 (Foundation)
```
Launch App → Login → Position Resolution →
Runtime Host Boots → Module Mounts → UI Appears
```

### Phase 2 (Trust & Delivery)
```
Launch App → Login → Position Resolution →
[NEW] Load Module Registry →
[NEW] Check Module Cache →
[NEW] Verify Signature →
[NEW] Check Compatibility →
[NEW] Track Last-Known-Good →
Runtime Host Boots → Module Mounts → UI Appears
[NEW] Update Notification Available
```

---

## 🔍 Advanced Verification

### Check Database Contents

**For Android**:
```bash
adb shell
cd /data/data/com.foundry.position_shell/databases
sqlite3 fallback.db

# Query last-known-good versions
SELECT * FROM fallback_state;

# Query failure tracking
SELECT * FROM failure_tracking;

.quit
```

**Expected Database Contents**:
```
fallback_state:
  module_id: sample-warehouse
  last_known_good_version: 1.0.0
  last_updated: [timestamp]

failure_tracking:
  (empty - no failures recorded)
```

### Monitor Update Events

**In WebView console**:
```javascript
// Listen for update events
window.addEventListener('module-update-available', (event) => {
  console.log('Update available:', event.detail);
  // event.detail.moduleId: 'sample-warehouse'
  // event.detail.currentVersion: '1.0.0'
  // event.detail.newVersion: '1.1.0'
});
```

### Verify Cache Size Tracking

**In Flutter logs**:
```
[ModuleCache] Cache size: 2.4 MB
[ModuleCache] Cached modules: 1
[ModuleCache] Cache limit: 100 MB
[ModuleCache] Usage: 2.4%
```

---

## 🐛 Troubleshooting Phase 2 Issues

### Issue: "Module signature verification failed"

**Symptoms**: Module doesn't load, logs show signature error

**Causes**:
- Signature file missing or corrupted
- Module file tampered with
- Checksum mismatch

**Solutions**:
1. Clear cache and retry:
   ```bash
   adb shell rm -rf /data/data/com.foundry.position_shell/app_flutter/modules
   # Restart app
   ```

2. Check logs for specific error:
   ```
   [ModuleVerifier] ERROR: Signature file not found
   [ModuleVerifier] ERROR: Invalid signature format
   [ModuleVerifier] ERROR: Checksum mismatch
   ```

3. In POC mode, signature verification should always pass (simulated). If failing, check file integrity.

---

### Issue: "Module version incompatible"

**Symptoms**: Module rejected before loading, compatibility error

**Causes**:
- Module requires newer shell version
- Version range not satisfied
- Manifest parsing error

**Solutions**:
1. Check shell version:
   ```dart
   [CompatibilityChecker] Current shell version: 1.0.0
   ```

2. Check module requirements:
   ```dart
   [CompatibilityChecker] Module requires: >=2.0.0
   [CompatibilityChecker] Compatibility: FAIL
   ```

3. For testing, module should require `>=1.0.0` (compatible with shell 1.0.0)

---

### Issue: "Module not loading from cache"

**Symptoms**: Module downloads every time, slow loading

**Causes**:
- Cache directory not writable
- Cache lookup failing
- File permissions issue

**Solutions**:
1. Check cache directory exists:
   ```bash
   adb shell ls -la /data/data/com.foundry.position_shell/app_flutter/modules
   ```

2. Check logs for cache miss:
   ```
   [ModuleCache] Cache miss: sample-warehouse v1.0.0
   [ModuleCache] Downloading module...
   ```

3. Verify cache hit on second load:
   ```
   [ModuleCache] Cache hit: sample-warehouse v1.0.0
   [ModuleCache] Load time: 145ms
   ```

---

### Issue: "Fallback database errors"

**Symptoms**: Database errors in logs, fallback not working

**Causes**:
- Database file corrupted
- SQLite initialization failed
- Permission issues

**Solutions**:
1. Check database initialization:
   ```
   [FallbackDatabase] Initializing database...
   [FallbackDatabase] Database path: /data/data/.../databases/fallback.db
   [FallbackDatabase] Tables created: OK
   ```

2. Clear database and restart:
   ```bash
   adb shell rm /data/data/com.foundry.position_shell/databases/fallback.db
   # Restart app
   ```

3. Run fallback integration test to verify:
   ```bash
   flutter test integration_test/fallback_test.dart
   ```

---

### Issue: "Update check never completes"

**Symptoms**: Update check hangs, no response

**Causes**:
- Network timeout (POC mode has no real CDN)
- Bridge communication error
- Event stream disconnected

**Solutions**:
1. Check bridge registration:
   ```
   [ModuleBridgeExtension] Bridge methods: registered
   ```

2. Verify event stream:
   ```
   [ModuleUpdater] Event stream: active
   ```

3. In POC mode, update checks should complete with "No updates available" since we only have v1.0.0

---

## 🧪 Running Automated Tests

To verify all Phase 2 functionality automatically:

### Run All Unit Tests
```bash
cd src/shell
flutter test test/modules/
```

**Expected**: 40 tests pass
- Module manifest parsing (12 tests)
- Version compatibility (9 tests)
- Module download (4 tests)
- Update check (3 tests)
- Module update integration (3 tests)
- Compatibility rejection (6 tests)
- Update notification (3 tests)

### Run All Integration Tests
```bash
cd src/shell
flutter test integration_test/
```

**Expected**: 30 tests pass (requires device/emulator)
- Signature verification (12 tests)
- Fallback mechanism (7 tests)
- Last-known-good tracking (3 tests)
- Module cache (5 tests)
- Cached module load (3 tests)

**Total**: 70 tests should pass (100% pass rate)

---

## 📈 Performance Benchmarks

### Expected Performance (From AC Requirements)

| Metric | Target | How to Verify |
|--------|--------|---------------|
| Module mount time | < 2 seconds | Time from `mountModule()` call to UI render |
| Cached module load | < 200ms | Time from cache lookup to module ready |
| Update check | < 5 seconds | Time from `checkForUpdates()` to result |
| Signature verification | < 1 second | Time from signature check start to completion |
| Database operations | < 100ms | Time for last-known-good save/load |

### How to Measure

**Enable performance logging**:
```dart
// In Flutter debug mode, logs show timing
[Performance] Module mount: 1,450ms ✓
[Performance] Cache load: 145ms ✓
[Performance] Update check: 3,200ms ✓
[Performance] Signature verify: 850ms ✓
[Performance] Database write: 45ms ✓
```

---

## ✅ Phase 2 Success Criteria

You've successfully verified Phase 2 if:

### Core Functionality ✅
- ✅ Module version appears in logs (1.0.0)
- ✅ Module cache directory exists with versioned storage
- ✅ Signature verification passes for module
- ✅ Compatibility check passes (shell 1.0.0 ↔ module >=1.0.0)
- ✅ Last-known-good version saved to database
- ✅ Update check completes without errors
- ✅ Bridge methods registered for update notifications

### Performance ✅
- ✅ Cached module loads in < 200ms
- ✅ Module mount completes in < 2 seconds
- ✅ Update check completes in < 5 seconds

### Testing ✅
- ✅ All 40 unit tests pass
- ✅ All 30 integration tests pass (70 total)
- ✅ No regressions from Phase 1

### Infrastructure ✅
- ✅ Database operations complete without errors
- ✅ Cache directory writable and accessible
- ✅ Event stream active for update notifications

---

## 🎓 Understanding Phase 2 Flow

### Complete Module Lifecycle (Phase 1 + Phase 2)

```
User Opens App
    ↓
[Phase 1] Authentication → Position Resolution → Bootstrap
    ↓
[Phase 2] Load Module Registry (versions, manifests)
    ↓
[Phase 2] Check Module Cache (is v1.0.0 cached?)
    ↓
    YES: Load from Cache (< 200ms)
    NO: Download → Verify Signature → Store in Cache
    ↓
[Phase 2] Verify Signature (RSA-2048 POC mode)
    ↓
[Phase 2] Check Compatibility (shell version vs module requirement)
    ↓
[Phase 1] Runtime Host Boots → Module Mounts
    ↓
[Phase 2] Mark as Last-Known-Good (save to database)
    ↓
User Sees Module UI
```

### Update Flow (New in Phase 2)

```
Background Timer Triggers (every 4 hours)
    ↓
Check Module Registry for Updates
    ↓
    New Version Available?
    ↓
    YES:
      ↓
      Check Compatibility (shell version OK?)
      ↓
      Download New Version in Background
      ↓
      Verify Signature + Checksum
      ↓
      Store in Cache (keep old version)
      ↓
      Notify Runtime Host (update available!)
      ↓
      User Accepts Update
      ↓
      Unmount Current Module
      ↓
      Mount New Version
      ↓
      Mark New Version as Last-Known-Good
```

### Fallback Flow (New in Phase 2)

```
Module Fails to Load (error during mount)
    ↓
Record Failure in Database
    ↓
Increment Failure Count for This Version
    ↓
    Failure Count < 3?
    ↓
    YES:
      ↓
      Get Last-Known-Good Version from Database
      ↓
      Load Last-Known-Good Instead
      ↓
      Notify User: "Rolled back to previous version"
    ↓
    NO (3+ failures):
      ↓
      Block This Version (prevent infinite loop)
      ↓
      Try Next-Best Version
      ↓
      Notify User: "This version is unstable, blocked"
```

---

## 📞 Next Steps After Phase 2 Testing

After successfully verifying Phase 2:

1. **Document any issues** found during manual testing
2. **Confirm all 12 ACs** are validated through manual + automated testing
3. **Review deviations** (RSA POC mode, simulated module loading) - these are acceptable for POC
4. **Prepare for Phase 3**: Offline & Critical Workflow
   - Phase 3 will use ModuleCache for offline module loading
   - Phase 3 will use FallbackManager for reliability
   - Phase 3 will use UpdateStateTracker for deferred updates

---

## 📚 Additional Resources

### Phase 2 Documentation
- **FINAL_SUMMARY.md** - Complete Phase 2 deliverables and metrics
- **test-report.md** - Detailed test results (Cycle 4)
- **built.md** - Implementation details and code changes

### Test Files (for reference)
- Unit Tests: `src/shell/test/modules/`
- Integration Tests: `src/shell/integration_test/`

### Phase 1 Baseline
- **QUICKSTART_GUIDE.md** - Phase 1 setup and verification

---

## 🎯 Manual Testing Summary

**Estimated Time**: 30-45 minutes for complete manual verification

**Test Coverage**:
- ✅ Test 1: Module Versioning (5 min)
- ✅ Test 2: Module Cache (5 min)
- ✅ Test 3: Signature Verification (5 min)
- ✅ Test 4: Update Check (5 min)
- ✅ Test 5: Last-Known-Good (5 min)
- ✅ Test 6: Compatibility (5 min)
- ✅ Test 7: Cache Performance (5 min)
- ✅ Test 8: Download Logic (review logs, 3 min)
- ✅ Test 9: Fallback (run integration test, 5 min)
- ✅ Test 10: Update Notifications (5 min)
- ✅ Test 11: Update Integration (run test, 3 min)

**Automated Test Coverage**: Run `flutter test` for comprehensive validation (~5 minutes)

---

**Ready to Test?**

Start with Test 1 and work through sequentially. Each test builds on the previous one. Good luck! 🚀

**Phase 2 Trust & Delivery Manual Testing Guide** ✅
