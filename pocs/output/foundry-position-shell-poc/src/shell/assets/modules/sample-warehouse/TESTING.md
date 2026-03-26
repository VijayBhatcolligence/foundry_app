# Phase 4: Offline Transaction Testing Guide

**Status**: Ready for Testing
**Architecture**: React-First IndexedDB with Flutter Connectivity Bridge
**Test Date**: _______________
**Tester**: _______________

---

## Overview

This document provides step-by-step instructions for testing the Phase 4 offline transaction workflow implementation. The system now uses:

- **React** owns all data (IndexedDB via RxDB)
- **React** owns all sync logic (JavaScript SyncManager)
- **Flutter** provides WebView + connectivity events only
- **No data flows through Flutter bridge**

---

## Prerequisites

### Required Environment

1. **Backend Server Running**
   - Location: `src/backend/server.js`
   - Start command: `node server.js`
   - URL: `http://192.168.0.163:3000`
   - Verify health: `http://192.168.0.163:3000/api/health`

2. **Flutter App Running**
   - Platform: Android device or emulator
   - Build: Debug or Release

3. **Testing Tools**
   - Chrome DevTools (for IndexedDB inspection)
   - Android Studio (for device logs)
   - Network toggle (Airplane mode)

---

## Test Scenarios

### TC-4E-01: Browser Testing (Chrome DevTools)

**Objective**: Verify IndexedDB storage and sync in desktop browser

**Steps**:

1. Open Chrome browser
2. Navigate to: `file:///path/to/sample-warehouse/index.html`
3. Open DevTools (F12) → Application tab → IndexedDB
4. Verify database `warehouse_offline_db` exists
5. Verify collection `transactions` exists
6. Create a test transaction with 5 line items
7. Check IndexedDB → transactions → verify record exists
8. Verify `syncStatus` field = "pending"
9. Wait 2-5 seconds (auto-sync should trigger)
10. Refresh IndexedDB view
11. Verify `syncStatus` changed to "synced"

**Expected Results**:
- ✅ IndexedDB database visible
- ✅ Transaction persisted with all fields
- ✅ Auto-sync triggered on save
- ✅ Status updated to "synced"

**Actual Results**: _______________

---

### TC-4E-02: Device Testing - Offline Persistence

**Objective**: Verify transactions persist across app restart

**Steps**:

1. Open app on Android device
2. Navigate to "Receiving Orders" → "Create Transaction"
3. Fill form:
   - PO Number: `PO-TEST-001`
   - Vendor: `Test Vendor Inc`
   - Add 10 line items with test data
4. Submit transaction
5. Verify success message: "Transaction saved!"
6. Navigate to "Offline Sync Queue"
7. Verify transaction appears with status "pending" or "synced"
8. **Close the app completely** (swipe away from recent apps)
9. Wait 10 seconds
10. Reopen the app
11. Navigate to "Offline Sync Queue"
12. Verify transaction still exists

**Expected Results**:
- ✅ Transaction saved successfully
- ✅ Appears in pending queue
- ✅ Persists after app restart
- ✅ No data loss

**Actual Results**: _______________

---

### TC-4E-03: Auto-Sync on Reconnect

**Objective**: Verify automatic sync when network reconnects

**Steps**:

1. Open app on Android device
2. **Enable Airplane Mode**
3. Verify network status badge shows "Offline" (red)
4. Create 3 transactions:
   - PO-OFFLINE-001
   - PO-OFFLINE-002
   - PO-OFFLINE-003
5. Verify all 3 appear in "Offline Sync Queue" with status "pending"
6. **Disable Airplane Mode** (turn off)
7. Wait 2-3 seconds
8. Observe network status badge changes to "Online" (green)
9. Watch "Offline Sync Queue" - transactions should sync automatically
10. Verify status changes from "pending" → "syncing" → "synced"
11. Verify all 3 transactions sync within 10 seconds

**Expected Results**:
- ✅ Transactions created while offline
- ✅ All appear as "pending" in queue
- ✅ Auto-sync triggers on reconnect
- ✅ Status updates visible in real-time
- ✅ All transactions reach "synced" state
- ✅ No manual sync button needed

**Actual Results**: _______________

---

### TC-4E-04: Retry Logic Testing

**Objective**: Verify retry logic handles failures correctly

**Steps**:

1. **Stop the backend server** (simulate API failure)
2. Create a transaction: `PO-RETRY-001`
3. Verify transaction appears as "pending"
4. Wait 2 seconds - sync should fail
5. Check transaction status - should still be "pending"
6. Verify `retryCount` = 1 (visible in queue details)
7. Wait 2 more seconds - retry should occur
8. Verify `retryCount` = 2
9. Wait 4 seconds - retry should occur
10. Verify `retryCount` = 3
11. After 3rd retry, status should change to "failed"
12. **Restart the backend server**
13. Click "Sync Now" button
14. Verify transaction syncs successfully

**Expected Results**:
- ✅ Sync fails when backend is down
- ✅ Retry count increments (2s, 4s, 8s backoff)
- ✅ Status changes to "failed" after 3 retries
- ✅ Manual sync works after server restart
- ✅ Failed transactions can be recovered

**Actual Results**: _______________

---

### TC-4E-05: Storage Quota Monitoring

**Objective**: Verify storage persistence and quota monitoring

**Steps**:

1. Open Chrome DevTools → Console
2. Create 20 transactions with 50 line items each
3. Watch console for storage logs
4. Look for messages like:
   - `[Storage] Using X MB of Y MB (Z%)`
   - `[Storage] Already persisted: true/false`
5. Navigate to Chrome → Settings → Site Settings → Storage
6. Verify storage quota granted to the site

**Expected Results**:
- ✅ Storage quota logs visible
- ✅ Persistent storage requested
- ✅ No storage errors
- ✅ Warning appears if usage > 80%

**Actual Results**: _______________

---

### TC-4E-06: 50-Line Transaction Support

**Objective**: Verify system handles maximum line items

**Steps**:

1. Create new transaction
2. Add 50 line items (use "Add Line Item" button)
3. Fill all 50 items with test data
4. Verify "Add Line Item" button becomes disabled at 50
5. Submit transaction
6. Verify success
7. Check IndexedDB - verify all 50 items saved
8. Wait for sync
9. Check backend database - verify all 50 items received

**Expected Results**:
- ✅ 50 items accepted
- ✅ Limit enforced (no 51st item)
- ✅ All 50 items saved to IndexedDB
- ✅ All 50 items synced to backend

**Actual Results**: _______________

---

### TC-4E-07: Manual Sync Button

**Objective**: Verify manual sync trigger works

**Steps**:

1. Enable Airplane Mode
2. Create 2 transactions
3. Disable Airplane Mode
4. **Do not wait for auto-sync**
5. Navigate to "Offline Sync Queue"
6. Click "Sync Now" button
7. Verify sync starts immediately
8. Verify both transactions sync successfully

**Expected Results**:
- ✅ "Sync Now" button visible
- ✅ Button triggers sync immediately
- ✅ Transactions sync successfully
- ✅ Button disabled while syncing

**Actual Results**: _______________

---

## Debugging Guide

### Issue: IndexedDB Not Initializing

**Symptoms**: Database not visible in DevTools

**Checks**:
1. Open Console - look for errors
2. Check: `[OfflineDB] Initializing RxDB...`
3. Check: RxDB and Dexie loaded correctly
4. Verify browser supports IndexedDB

**Solution**:
- Refresh page
- Clear IndexedDB: DevTools → Application → IndexedDB → Delete database
- Check browser compatibility

---

### Issue: Auto-Sync Not Triggering

**Symptoms**: Transactions stuck as "pending"

**Checks**:
1. Verify network status badge shows "Online"
2. Check Console for: `[SyncManager] Starting sync...`
3. Verify backend server is running and reachable
4. Check network connectivity

**Solution**:
- Toggle Airplane Mode off/on
- Click "Sync Now" manually
- Restart app
- Check backend health endpoint

---

### Issue: Sync Failures

**Symptoms**: Transactions stuck as "syncing" or "failed"

**Checks**:
1. Check backend server logs
2. Verify API endpoint: `http://192.168.0.163:3000/api/transactions`
3. Check CORS headers
4. Verify transaction data format

**Solution**:
- Check backend logs for errors
- Test API with Postman
- Verify network connectivity
- Check transaction `lastError` field in IndexedDB

---

### Issue: Data Loss After Restart

**Symptoms**: Transactions disappear after closing app

**Checks**:
1. Check: `[Storage] Persistence granted: true`
2. Verify IndexedDB not in incognito mode
3. Check browser storage settings

**Solution**:
- Request persistent storage explicitly
- Check browser storage quota
- Avoid incognito mode
- Use Android app (more reliable persistence)

---

## Chrome DevTools Inspection

### View IndexedDB Data

1. Open DevTools (F12)
2. Go to **Application** tab
3. Expand **IndexedDB** → `warehouse_offline_db` → `transactions`
4. Click on `transactions` to view all records
5. Expand a record to see all fields:
   - `transactionId`
   - `poNumber`
   - `vendor`
   - `lineItems` (array)
   - `syncStatus` ("pending", "syncing", "synced", "failed")
   - `retryCount`
   - `lastError`

### Monitor Console Logs

Filter by:
- `[OfflineDB]` - Database operations
- `[SyncManager]` - Sync activity
- `[Storage]` - Storage quota
- `[ConnectivityBridge]` - Network changes

---

## Test Results Summary

| Test Case | Status | Notes |
|-----------|--------|-------|
| TC-4E-01: Browser Testing | ⬜ Pass / ⬜ Fail | |
| TC-4E-02: Offline Persistence | ⬜ Pass / ⬜ Fail | |
| TC-4E-03: Auto-Sync on Reconnect | ⬜ Pass / ⬜ Fail | |
| TC-4E-04: Retry Logic | ⬜ Pass / ⬜ Fail | |
| TC-4E-05: Storage Quota | ⬜ Pass / ⬜ Fail | |
| TC-4E-06: 50-Line Transaction | ⬜ Pass / ⬜ Fail | |
| TC-4E-07: Manual Sync | ⬜ Pass / ⬜ Fail | |

---

## Success Criteria (All Must Pass)

- ✅ User can create 50-line receiving transaction
- ✅ Transaction writes to IndexedDB
- ✅ Transaction visible in Chrome DevTools
- ✅ Works completely offline (airplane mode)
- ✅ Transaction persists across app restart
- ✅ Auto-sync triggers when network reconnects
- ✅ Status updates: pending → syncing → synced
- ✅ Pending transactions list shows all queued items
- ✅ Network status badge shows correct state
- ✅ Manual sync button works

---

## Known Limitations

1. **Browser Persistence**: IndexedDB persistence in mobile browsers is less reliable than native apps
2. **Storage Eviction**: Browser may evict IndexedDB data under storage pressure
3. **Network Detection**: Browser's `navigator.onLine` is not always accurate
4. **Sync Timing**: 2-second delay between syncs is for demo visibility

---

## Additional Notes

- Backend server must be accessible on local network
- Use actual device IP (not localhost) for testing on Android
- Airplane Mode is the most reliable way to test offline functionality
- Clear IndexedDB between test runs to avoid data conflicts

---

**Test Complete**: ⬜ Yes / ⬜ No
**Overall Status**: ⬜ Pass / ⬜ Fail
**Tester Signature**: _______________
**Date**: _______________
