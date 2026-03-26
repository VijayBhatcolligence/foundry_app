# Phase 4: Demo-able Transaction Workflow - Implementation Plan

**Agent**: PLANNER
**Created**: 2026-03-14
**Status**: PLANNING COMPLETE
**Architecture**: React-First / PWA Pattern with IndexedDB

---

## Executive Summary

This plan implements Scenario W-3 (Full Offline Receiving Transaction) using a **React-first architecture** where:
- React owns all data storage (IndexedDB via RxDB)
- React owns all sync logic (JavaScript SyncManager)
- Flutter provides only WebView hosting + connectivity events
- No data flows through Flutter bridge

**Key Deliverable**: 50-line receiving transaction works completely offline with auto-sync on reconnect.

---

## Phase Breakdown

### Phase 4A: IndexedDB Storage Layer (3-4 hours)

**Objective**: Implement RxDB-based IndexedDB storage for transactions

**Files to Create**:

1. **src/shell/assets/modules/sample-warehouse/db/schema.ts** (~150 lines)
   - RxDB database initialization
   - Transaction schema definition
   - Persistent storage request
   - Storage quota monitoring

2. **src/shell/assets/modules/sample-warehouse/db/hooks/useDatabase.ts** (~50 lines)
   - React hook for database access
   - Singleton database instance
   - Database initialization on app load

**Implementation Steps**:

1. Install dependencies
2. Create transaction schema
3. Implement initDatabase() function
4. Create useDatabase() hook
5. Test in browser DevTools

**Acceptance Criteria**:
- ✅ RxDB initializes successfully
- ✅ IndexedDB visible in Chrome DevTools
- ✅ Persistent storage request succeeds
- ✅ Database schema validates correctly

---

### Phase 4B: JavaScript SyncManager (4-5 hours)

**Objective**: Implement auto-sync on reconnect with retry logic

**Files to Create**:

1. **src/shell/assets/modules/sample-warehouse/sync/SyncManager.ts** (~300 lines)
2. **src/shell/assets/modules/sample-warehouse/api/TransactionAPI.ts** (~100 lines)

**Implementation Steps**:

1. Create SyncManager class
2. Implement connectivity monitoring
3. Implement syncPendingTransactions()
4. Implement syncTransaction() with retry logic
5. Create TransactionAPI
6. Add 2-second delay for demo visibility

**Acceptance Criteria**:
- ✅ Sync triggers on navigator.onLine = true
- ✅ Sync triggers on Flutter connectivity event
- ✅ Transactions sync in batches of 10
- ✅ Failed syncs retry with backoff
- ✅ Status transitions visible in IndexedDB

---

### Phase 4C: React UI Components (4-5 hours)

**Objective**: Build transaction entry and pending list UI

**Components to Build**:

1. ReceivingTransactionForm (150-200 lines)
2. LineItemEntry (60-80 lines)
3. PendingTransactionsList (100-120 lines)
4. NetworkStatusBadge (30-40 lines)
5. SyncProgressIndicator (40-50 lines)

**Acceptance Criteria**:
- ✅ Form validates before submission
- ✅ Line items limited to 50
- ✅ Transaction writes to IndexedDB
- ✅ Pending list updates reactively
- ✅ Network badge shows correct status

---

### Phase 4D: Flutter Connectivity Bridge (1-2 hours)

**Objective**: Simplify bridge to only handle connectivity events

**Files to Create**:
1. **src/shell/lib/bridge/connectivity_bridge_extension.dart** (~80 lines)

**Files to Modify**:
1. **src/shell/lib/bridge/shell_bridge.dart** - Remove offline methods

**Acceptance Criteria**:
- ✅ Connectivity events injected into WebView
- ✅ window.onConnectivityChange() callable from React
- ✅ Events fire on airplane mode toggle
- ✅ Old offline methods removed

---

### Phase 4E: Integration Testing (2-3 hours)

**Test Cases**:
- TC-4E-01: Browser Testing
- TC-4E-02: Device Testing - Offline Persistence
- TC-4E-03: Auto-Sync on Reconnect
- TC-4E-04: Retry Logic
- TC-4E-05: Storage Quota

**Acceptance Criteria**:
- ✅ All 5 test cases pass
- ✅ IndexedDB persists across app restarts
- ✅ Auto-sync triggers reliably
- ✅ Retry logic works as expected

---

## File Manifest Summary

### Files to Create (6 files)

**React Side**:
1. src/shell/assets/modules/sample-warehouse/db/schema.ts (~150 lines)
2. src/shell/assets/modules/sample-warehouse/db/hooks/useDatabase.ts (~50 lines)
3. src/shell/assets/modules/sample-warehouse/sync/SyncManager.ts (~300 lines)
4. src/shell/assets/modules/sample-warehouse/api/TransactionAPI.ts (~100 lines)

**Flutter Side**:
5. src/shell/lib/bridge/connectivity_bridge_extension.dart (~80 lines)

**Testing**:
6. test/integration/offline_workflow.test.js (~150 lines)

### Files to Modify (2 files)

1. src/shell/assets/modules/sample-warehouse/index.html
   - Add ~500 lines for new components
   - Target: ~1300 lines total

2. src/shell/lib/bridge/shell_bridge.dart
   - Remove 3 offline methods
   - Add connectivity initialization

### Dependencies to Add

**package.json**:
- rxdb: ^15.0.0
- rxdb-plugin-storage-dexie: ^15.0.0
- uuid: ^9.0.0

---

## Risk Mitigation

### Risk 1: IndexedDB Storage Eviction
**Probability**: Medium (30%)
**Impact**: High (data loss)
**Mitigation**: Request persistent storage, monitor quota, warn at 80%

### Risk 2: Connectivity Detection Unreliable
**Probability**: Low (10%)
**Impact**: Medium (delayed sync)
**Mitigation**: Flutter connectivity_plus as source of truth, manual sync button

### Risk 3: 50-Item Performance
**Probability**: Low (15%)
**Impact**: Low (slower writes)
**Mitigation**: RxDB indexes, reduce to 25 if needed

---

## Estimated Effort

| Phase | Estimated Hours |
|-------|----------------|
| 4A: IndexedDB Storage | 3-4 hours |
| 4B: SyncManager | 4-5 hours |
| 4C: React UI | 4-5 hours |
| 4D: Flutter Bridge | 1-2 hours |
| 4E: Testing | 2-3 hours |
| **Total** | **14-19 hours** |

---

## Success Metrics

- ✅ Transaction writes to IndexedDB in <100ms
- ✅ 50-line transactions supported
- ✅ IndexedDB persists across restarts
- ✅ Auto-sync within 2 seconds of reconnect
- ✅ Sync success rate >95%

---

**PLANNER Status**: ✅ PLAN COMPLETE - Ready for Validation
**Total LOC**: ~1,730 lines (new + modified)
**Architecture**: React-First / PWA Pattern
