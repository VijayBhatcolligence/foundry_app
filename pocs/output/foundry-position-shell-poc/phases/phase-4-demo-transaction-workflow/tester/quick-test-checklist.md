# Quick Test Checklist - Phase 4
# 10-Minute Manual Test

Print this page and check off each test as you perform it.

---

## Setup (2 minutes)

- [ ] Backend server running (`node server.js`)
- [ ] Browser or Flutter app ready
- [ ] Chrome DevTools open (F12)
- [ ] Backend accessible at `http://192.168.0.163:3000`

---

## Test 1: Basic Transaction Creation (2 minutes)

- [ ] Navigate to "Receiving Orders" → "Create Transaction"
- [ ] Enter PO Number: `TEST-001`
- [ ] Enter Vendor: `Test Vendor`
- [ ] Click "Add Line Item"
- [ ] Fill line item fields:
  - [ ] SKU: `ITEM-001`
  - [ ] Description: `Test Item`
  - [ ] Quantity: `10`
  - [ ] Location: `A-1-1`
- [ ] Click "Submit Transaction"
- [ ] Verify success message appears
- [ ] Open DevTools → Application → IndexedDB → `warehouse_offline_db` → `transactions`
- [ ] Verify transaction exists
- [ ] Verify `syncStatus` = `"synced"`

**Result**: PASS / FAIL

---

## Test 2: Offline Functionality (2 minutes)

**Browser Test**:
- [ ] DevTools → Network tab → Check "Offline"

**Device Test**:
- [ ] Enable Airplane Mode

**Continue**:
- [ ] Verify network badge shows "Offline" (red)
- [ ] Create new transaction (PO: `OFFLINE-001`)
- [ ] Click Submit
- [ ] Verify message: "Will sync when online"
- [ ] Check IndexedDB → `syncStatus` = `"pending"`
- [ ] Navigate to "Offline Sync Queue"
- [ ] Verify transaction appears in queue

**Result**: PASS / FAIL

---

## Test 3: Auto-Sync on Reconnect (2 minutes)

- [ ] With transaction still pending from Test 2
- [ ] **Browser**: Uncheck "Offline" in DevTools
- [ ] **Device**: Disable Airplane Mode
- [ ] Verify network badge changes to "Online" (green)
- [ ] Wait 2-3 seconds
- [ ] Watch "Offline Sync Queue" for status change
- [ ] Verify status: `pending` → `syncing` → `synced`
- [ ] Refresh IndexedDB view
- [ ] Verify `syncStatus` = `"synced"`

**Result**: PASS / FAIL

---

## Test 4: Persistence After Restart (2 minutes)

- [ ] Create transaction offline (PO: `PERSIST-001`)
- [ ] Verify in queue with status "pending"
- [ ] **Browser**: Close browser completely
- [ ] **Device**: Force stop app (swipe away)
- [ ] Wait 10 seconds
- [ ] Reopen browser/app
- [ ] Navigate to "Offline Sync Queue"
- [ ] Verify transaction still exists
- [ ] Verify data intact (PO number, vendor, line items)

**Result**: PASS / FAIL

---

## Test 5: 50-Line Item Limit (Optional - 2 minutes)

- [ ] Create new transaction
- [ ] Click "Add Line Item" multiple times (aim for 50)
- [ ] Verify button disabled at 50 items
- [ ] Try clicking "Add Line Item" again
- [ ] Verify error message: "Maximum 50 line items reached"
- [ ] Fill 10 items minimum (or all 50 if time permits)
- [ ] Submit transaction
- [ ] Verify success

**Result**: PASS / FAIL

---

## Test 6: Remove Line Items (1 minute)

- [ ] Create new transaction
- [ ] Add 5 line items
- [ ] Click "Remove" on 2nd item
- [ ] Verify item removed from list
- [ ] Verify remaining 4 items
- [ ] Submit transaction
- [ ] Check IndexedDB → `lineItems` array
- [ ] Verify only 4 items saved

**Result**: PASS / FAIL

---

## Test 7: Manual Sync (1 minute)

- [ ] Enable Airplane Mode / Offline mode
- [ ] Create transaction (PO: `MANUAL-001`)
- [ ] Disable Airplane Mode / Offline mode
- [ ] Immediately navigate to "Offline Sync Queue"
- [ ] Click "Sync Now" button (don't wait for auto-sync)
- [ ] Verify sync starts immediately
- [ ] Verify status changes to "synced" within 2 seconds

**Result**: PASS / FAIL

---

## Visual Checks

- [ ] Network status badge visible
- [ ] Badge color correct (green=online, red=offline)
- [ ] Sync progress indicator shows during sync
- [ ] Transaction count visible in queue
- [ ] Status colors correct:
  - [ ] Pending = Orange
  - [ ] Syncing = Blue
  - [ ] Synced = Green
  - [ ] Failed = Red

**Result**: PASS / FAIL

---

## IndexedDB Inspection

Open DevTools → Application → IndexedDB → `warehouse_offline_db` → `transactions`

Verify fields exist:
- [ ] `transactionId` (UUID format)
- [ ] `poNumber` (string)
- [ ] `vendor` (string)
- [ ] `lineItems` (array of objects)
- [ ] `createdAt` (timestamp number)
- [ ] `syncStatus` (enum: pending/syncing/synced/failed)
- [ ] `retryCount` (number)
- [ ] `lastError` (null or string)
- [ ] `lastSyncAttempt` (null or number)

**Result**: PASS / FAIL

---

## Backend Verification

- [ ] Open backend terminal
- [ ] Check logs for: `[POST /api/transactions] Transaction xxx inserted`
- [ ] Verify transaction ID matches frontend
- [ ] Check SQLite database:
  ```bash
  sqlite3 backend_transactions.db
  SELECT * FROM transactions ORDER BY id DESC LIMIT 5;
  ```
- [ ] Verify transactions received

**Result**: PASS / FAIL

---

## Final Checks

- [ ] No errors in browser console
- [ ] No errors in backend logs
- [ ] All transactions eventually sync
- [ ] UI responsive and smooth
- [ ] No data loss observed

**Overall Result**: PASS / FAIL

---

## Quick Test Score

Count your PASS results:

- **10/10**: Perfect - Ready for demo
- **8-9/10**: Excellent - Minor issues
- **6-7/10**: Good - Some investigation needed
- **<6/10**: Issues found - Review test-report.md

**Your Score**: _____ / 10

---

## Notes

Write any issues found:

```
Issue 1:

Issue 2:

Issue 3:
```

---

## Tester Information

- **Name**: _______________________
- **Date**: _______________________
- **Environment**: Browser / Android Device
- **Backend Version**: _______________________
- **Time Taken**: _______ minutes

---

**Next Steps**:
- If PASS: Proceed to stakeholder demo
- If FAIL: Review `test-report.md` for detailed analysis
- Report issues: Document in notes section above

---

**End of Quick Test Checklist**
