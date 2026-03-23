# ADR-001: Complete Module Cache Integration

**Status**: Proposed
**Date**: 2026-03-16
**Decision Makers**: Technical Architecture Team
**Related**: Phase 2 Trust & Delivery, IMPLEMENTATION_REVIEW.md

---

## Context

Phase 2 implemented a `ModuleCache` service with complete cache directory management, multi-version storage, and cache lookup APIs. However, the actual module loading flow still uses Phase 1's bundled module approach and does not load modules from the cache.

**Current State**:
- ✅ `ModuleCache` service exists and works
- ✅ Cache directory structure created (`app_flutter/modules/`)
- ✅ Multi-version storage implemented
- ❌ Module loading flow does NOT use cache
- ❌ Performance threshold `< 200ms` not measured

**Console Evidence**:
```
I/flutter: [ModuleCache] Checking cache for module: sample-warehouse
I/flutter: [ModuleCache] Module not in cache, would download and verify
```

The cache checks for modules but doesn't actually store or load them yet.

---

## Baseline Assumption Being Changed

**Original Assumption** (from `foundry-position-shell-parity-evaluation.md`):
```
Slice 2 — Trust and Delivery proves:
- cached module load < 200ms
- module update without shell release
```

**Current Reality**:
- Cache service exists but is not in the critical path
- Modules still load from bundled Phase 1 approach
- Cannot verify < 200ms threshold

---

## PoC Evidence That Exposed The Problem

### From Implementation Review

1. **Integration Gap**: Phase 2 integration wired up service initialization but didn't complete the module load flow refactoring
2. **Test Evidence**: All 70 Phase 2 tests pass, but they test the cache service in isolation, not integrated into the app's actual module loading
3. **Console Logs**: Show cache checks happening but no cache hits/stores

### From Reference Requirements

**Scenario W-5** (`foundry-position-shell-poc-scenarios.md`):
```
Success Criteria:
- Second load of position module < 200ms from local cache
- No network request for cached assets
- Cache survives app restart
```

**Current Status**:
- ❌ Second load NOT from cache (still bundled)
- ❌ < 200ms not measured
- ✅ Cache WOULD survive restart (file system persistence works)

---

## Problem Statement

The module cache infrastructure is complete and tested, but **not integrated into the actual module loading flow**. This means:

1. Modules cannot be cached after download
2. Subsequent loads don't benefit from cache performance
3. Offline module loading cannot work (depends on cache)
4. Performance threshold `< 200ms` cannot be validated

**Impact**:
- **Phase 2 Parity**: Incomplete - cache infrastructure exists but isn't used
- **Phase 3 Blocker**: Offline module loading requires working cache integration
- **User Experience**: No performance benefit from caching yet

---

## Options

### Option A: Complete Integration in Phase 3 (RECOMMENDED)

**Description**: Integrate cache into module loading flow as part of Phase 3 (Offline & Critical Workflow)

**Approach**:
1. Phase 3 needs offline module loading anyway
2. Offline loading REQUIRES cache to work
3. Natural integration point when building offline support
4. Can measure < 200ms threshold during Phase 3

**Implementation**:
```dart
// In WebView module loading (runtime-host or shell bridge):
Future<void> loadModule(String moduleId, String version) async {
  // 1. Check cache first
  final cachedPath = await moduleCache.getCachedModulePath(moduleId, version);

  if (cachedPath != null) {
    // Load from cache (fast path)
    await loadModuleFromCache(cachedPath);
  } else {
    // Download, verify, store in cache, then load
    final downloadedPath = await moduleDownloader.download(/*...*/);
    await moduleVerifier.verify(downloadedPath);
    await moduleCache.storeModule(moduleId, version, downloadedPath);
    await loadModuleFromCache(cachedPath);
  }
}
```

**Pros**:
- ✅ Natural fit with Phase 3 scope (offline)
- ✅ Can be tested end-to-end in offline scenarios
- ✅ Doesn't delay Phase 3 start
- ✅ Single integration effort (not two separate passes)

**Cons**:
- ⚠️ Phase 2 technically incomplete (infrastructure only)
- ⚠️ Cannot measure < 200ms until Phase 3

**Timeline**: Phase 3 Cycle 1 (estimated 3-5 days)

**Risk**: Low - infrastructure already built and tested

---

### Option B: Complete Integration Now (Before Phase 3)

**Description**: Pause before Phase 3 and complete cache integration immediately

**Approach**:
1. Refactor WebView module loading flow
2. Add download/cache/verify pipeline
3. Measure < 200ms threshold
4. Update documentation

**Pros**:
- ✅ Phase 2 fully complete before Phase 3
- ✅ Can measure performance now
- ✅ Clean phase boundaries (Phase 2 = complete trust & delivery)

**Cons**:
- ❌ Duplicates work (will touch same code again in Phase 3 for offline)
- ❌ Delays Phase 3 start by 2-3 days
- ❌ Adds testing burden (test now + test again in Phase 3)

**Timeline**: 2-3 days additional work before Phase 3

**Risk**: Low - but creates rework when Phase 3 adds offline

---

### Option C: Minimal Integration (Hybrid)

**Description**: Add just enough integration to prove cache works, defer full flow to Phase 3

**Approach**:
1. Add cache store on first module load (one-time)
2. Add cache load on second app launch
3. Measure < 200ms
4. Leave full download/verify/update flow for Phase 3

**Pros**:
- ✅ Validates < 200ms threshold now
- ✅ Proves cache works end-to-end
- ✅ Minimal time investment (~1 day)

**Cons**:
- ⚠️ Partial integration (not complete download/update flow)
- ⚠️ Still requires Phase 3 work to finish

**Timeline**: 1 day

**Risk**: Medium - might create technical debt with partial implementation

---

## Decision

**RECOMMENDED: Option A - Complete Integration in Phase 3**

**Rationale**:

1. **Natural Fit**: Phase 3 (Offline & Critical Workflow) MUST have cache working for offline module loading
2. **Efficiency**: One complete integration effort instead of partial now + finish later
3. **Testing**: Phase 3 offline scenarios thoroughly test cache integration
4. **Documentation**: Phase 2 "Trust & Delivery infrastructure" is accurate - infrastructure is complete
5. **Velocity**: Doesn't delay Phase 3 start

**Acceptance Criteria for Completion** (in Phase 3):
- [ ] Module first load downloads and stores in cache
- [ ] Module second load reads from cache (no network)
- [ ] Cache load time measured: must be < 200ms
- [ ] Cache survives app restart
- [ ] Cache integration works offline (no network available)

---

## Impact Assessment

### On Upstream Foundry Architecture

**Impact**: None

Cache integration is an implementation detail, not an architecture change. The upstream architecture already assumes module caching.

### On Runtime Contract Shape

**Impact**: None

Module loading contract unchanged. Cache is transparent to position modules.

### On Auth and Trust Boundary

**Impact**: None

Cache stores verified modules after signature check. Trust boundary preserved.

### On Compiler Target Expectations

**Impact**: None

Compiler-generated modules unaffected. Cache is infrastructure, not contract.

### On Delivery, Activation, and Rollback Model

**Impact**: Positive

Completing cache integration enables:
- Faster module loads (< 200ms)
- Offline module availability
- Last-known-good fallback from cache

---

## Classification

**Deviation Type**: Implementation gap, not architectural change

**Production Blocking**: No - infrastructure exists, integration is straightforward

**Recommendation**: Complete in Phase 3 as part of offline support

---

## Action Items

### If Option A Approved (Recommended):

1. [ ] Document in Phase 3 plan: "Complete Phase 2 cache integration"
2. [ ] Add to Phase 3 Cycle 1 deliverables:
   - Cache-based module loading
   - Performance measurement (< 200ms threshold)
   - Offline cache availability
3. [ ] Update `foundry-position-shell-parity-evaluation.md`:
   - Note: "Phase 2 delivers cache infrastructure; Phase 3 integrates into load flow"
4. [ ] Update `foundry-position-shell-poc-scenarios.md`:
   - Scenario W-5 status: "In progress - infrastructure complete, integration in Phase 3"

### If Option B or C Approved:

1. [ ] Create integration task before Phase 3
2. [ ] Assign to autonomous build agent or manual completion
3. [ ] Measure < 200ms threshold
4. [ ] Update documentation with results
5. [ ] Then proceed to Phase 3

---

## Success Metrics

**Completion Criteria**:
- Module loads from cache in < 200ms (measured on device)
- Cache hit rate > 90% on second and subsequent loads
- Zero network requests for cached modules
- Cache survives app restart
- Works offline (no network available)

**Verification**:
```bash
# Run app, load module (first time - downloads)
flutter run

# Restart app, load module (second time - from cache)
# Measure time from "load module" to "module mounted"
# Expected: < 200ms

# Verify in logs:
[ModuleCache] Cache hit: sample-warehouse v1.0.0
[ModuleCache] Load time: 145ms ✓
```

---

## Status

**Current**: Proposed
**Next Step**: Stakeholder review and approval
**Decision Date**: [Pending]
**Approved By**: [Pending]

---

**ADR-001 COMPLETE**
