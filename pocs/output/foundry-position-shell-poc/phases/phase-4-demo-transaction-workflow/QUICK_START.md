# Phase 4: Quick Start Guide

**Get the offline transaction workflow running in 5 minutes**

---

## Prerequisites Check

Before starting, ensure you have:

- ✅ Node.js installed (for backend server)
- ✅ Flutter SDK installed (for mobile app)
- ✅ Android device or emulator (optional - can test in browser first)
- ✅ Chrome browser (for IndexedDB inspection)

---

## Option 1: Browser Testing (Fastest - 2 minutes)

### Step 1: Start Backend Server

```bash
cd C:\Users\bijay\OneDrive\Desktop\auto_agent3\pocs\output\foundry-position-shell-poc\src\backend
node server.js
```

**Expected output**:
```
Server running on: http://localhost:3000
Database: .../backend_transactions.db
Health check: http://localhost:3000/api/health
```

### Step 2: Open Warehouse Module in Browser

```bash
# File path (open in Chrome)
C:\Users\bijay\OneDrive\Desktop\auto_agent3\pocs\output\foundry-position-shell-poc\src\shell\assets\modules\sample-warehouse\index.html
```

**Or use a local web server**:
```bash
cd C:\Users\bijay\OneDrive\Desktop\auto_agent3\pocs\output\foundry-position-shell-poc\src\shell\assets\modules\sample-warehouse
python -m http.server 8000
# Then open: http://localhost:8000
```

### Step 3: Test Offline Workflow

1. **Open Chrome DevTools** (F12)
2. Click **"Receiving Orders"** card
3. Click **"Create Transaction"** tab
4. Fill form:
   - PO Number: `TEST-001`
   - Vendor: `Test Vendor`
   - Add 5 line items (fill all fields)
5. Click **"Submit Transaction"**
6. See success message
7. Go to DevTools → **Application** → **IndexedDB** → `warehouse_offline_db` → `transactions`
8. Verify transaction is there with `syncStatus: "synced"`

**Screenshot locations**:
- IndexedDB: DevTools → Application tab
- Console logs: DevTools → Console tab (filter: `[OfflineDB]` or `[SyncManager]`)

---

## Option 2: Mobile Testing (Full Experience - 10 minutes)

### Step 1: Start Backend Server (Same as above)

```bash
cd C:\Users\bijay\OneDrive\Desktop\auto_agent3\pocs\output\foundry-position-shell-poc\src\backend
node server.js
```

### Step 2: Update Backend URL in Module

**IMPORTANT**: The module needs to point to your computer's IP address (not localhost)

1. Find your IP address:
   ```bash
   # Windows
   ipconfig
   # Look for "IPv4 Address" (e.g., 192.168.0.163)

   # macOS/Linux
   ifconfig
   # Look for "inet" under active network
   ```

2. Verify the URL in `TransactionAPI.js` matches your IP:
   ```javascript
   // Should be:
   const API_BASE_URL = 'http://YOUR_IP_HERE:3000';
   ```

3. Also update in `index.html` (search for `192.168.0.163` and replace with your IP)

### Step 3: Run Flutter App

```bash
cd C:\Users\bijay\OneDrive\Desktop\auto_agent3\pocs\output\foundry-position-shell-poc\src\shell
flutter run
```

Wait for app to install and launch on device/emulator.

### Step 4: Test Offline Workflow

1. **Login** (use test credentials if prompted)
2. Navigate to **"Warehouse Clerk"** module
3. Click **"Receiving Orders"**
4. **Enable Airplane Mode** on device
5. Create transaction (PO: `OFFLINE-001`, Vendor: `Test`, 10 items)
6. Submit → See "Will sync when online" message
7. Click **"Offline Sync Queue"** → See transaction with "pending" status
8. **Disable Airplane Mode**
9. Watch transaction status change: pending → syncing → synced (takes ~2-5 seconds)

---

## Quick Tests

### Test 1: IndexedDB Persistence (30 seconds)

```
1. Create transaction
2. Close browser completely
3. Reopen same page
4. Go to "Offline Sync Queue"
✅ Transaction should still be there
```

### Test 2: Auto-Sync (1 minute)

```
1. Enable Airplane Mode
2. Create 3 transactions
3. All appear as "pending"
4. Disable Airplane Mode
5. Wait 5 seconds
✅ All should change to "synced"
```

### Test 3: 50-Item Limit (1 minute)

```
1. Create new transaction
2. Click "Add Line Item" 50 times
3. Try to add 51st item
✅ Button should be disabled at 50
```

### Test 4: Manual Sync (30 seconds)

```
1. Enable Airplane Mode
2. Create 1 transaction
3. Disable Airplane Mode
4. DON'T WAIT - immediately click "Sync Now"
✅ Transaction should sync immediately
```

---

## Verify Implementation

### Check Files Exist

```bash
cd C:\Users\bijay\OneDrive\Desktop\auto_agent3\pocs\output\foundry-position-shell-poc

# React/JS files
ls src/shell/assets/modules/sample-warehouse/db/schema.js
ls src/shell/assets/modules/sample-warehouse/db/useDatabase.js
ls src/shell/assets/modules/sample-warehouse/sync/SyncManager.js
ls src/shell/assets/modules/sample-warehouse/api/TransactionAPI.js

# Flutter files
ls src/shell/lib/bridge/connectivity_bridge_extension.dart

# Documentation
ls src/shell/assets/modules/sample-warehouse/TESTING.md
ls phases/phase-4-demo-transaction-workflow/IMPLEMENTATION_SUMMARY.md
```

All files should exist.

### Check Dependencies Installed

```bash
cd C:\Users\bijay\OneDrive\Desktop\auto_agent3\pocs\output\foundry-position-shell-poc\src\shell\assets\modules\sample-warehouse

# Check package.json exists
ls package.json

# Check node_modules
ls node_modules/rxdb
ls node_modules/dexie
ls node_modules/uuid
```

---

## Troubleshooting

### Backend Won't Start

**Error**: "Port 3000 already in use"

**Solution**:
```bash
# Windows - Kill process on port 3000
netstat -ano | findstr :3000
taskkill /PID <PID> /F

# Then restart server
node server.js
```

### "Cannot reach backend" Error

**Solution**:
1. Verify backend server is running (check terminal)
2. Test health endpoint: `http://192.168.0.163:3000/api/health`
3. Check firewall allows port 3000
4. Verify IP address matches your computer

### IndexedDB Not Visible

**Solution**:
1. Refresh page (Ctrl+R)
2. Check Console for errors
3. Try incognito mode
4. Clear browser cache and reload

### Auto-Sync Not Working

**Solution**:
1. Check network badge shows "Online" (green)
2. Check Console for `[SyncManager]` logs
3. Toggle Airplane Mode off/on
4. Click "Sync Now" manually

### "RxDB is not defined" Error

**Solution**:
1. Verify CDN scripts loaded (check Network tab)
2. Check internet connection (CDN requires internet)
3. Wait 2-3 seconds for scripts to load
4. Refresh page

---

## Success Indicators

You'll know it's working when you see:

1. **In Browser**:
   - ✅ Network badge shows "Online" or "Offline"
   - ✅ "Offline Sync Queue" shows transaction count
   - ✅ Transactions appear in queue after submit
   - ✅ Status changes from "pending" to "synced"

2. **In Console**:
   ```
   [OfflineDB] Initializing RxDB...
   [OfflineDB] Database created
   [OfflineDB] Collections added
   [Storage] Persistence granted: true
   [SyncManager] Initialized. Online: true
   [SyncManager] Starting sync...
   [SyncManager] ✓ TXN-xxx synced
   ```

3. **In IndexedDB** (DevTools):
   - ✅ Database: `warehouse_offline_db`
   - ✅ Collection: `transactions`
   - ✅ Records with all fields populated
   - ✅ syncStatus: "synced"

4. **In Backend Logs**:
   ```
   [POST /api/transactions] Received: {...}
   [POST /api/transactions] Transaction TXN-xxx inserted
   ```

---

## Next Steps

After basic testing works:

1. Read full testing guide: `TESTING.md`
2. Test all 7 test cases (TC-4E-01 through TC-4E-07)
3. Test on actual Android device (not just emulator)
4. Test with 50-line transactions
5. Test persistence across app restarts
6. Test retry logic (stop backend, create transaction, restart backend)

---

## Demo Script (5 minutes)

Perfect for showing to stakeholders:

1. **Show offline capability**:
   - Enable Airplane Mode
   - Create transaction with 10 items
   - Show success message
   - Show in pending queue

2. **Show persistence**:
   - Close app completely
   - Reopen
   - Show transaction still in queue

3. **Show auto-sync**:
   - Disable Airplane Mode
   - Watch transaction sync automatically
   - Status changes in real-time
   - Show in backend (check database)

4. **Show 50-item support**:
   - Create transaction
   - Add 50 items
   - Submit
   - Show all 50 items in IndexedDB

5. **Show retry logic**:
   - Stop backend server
   - Create transaction
   - Watch retry attempts
   - Restart backend
   - Click "Sync Now"
   - Transaction syncs

---

## Performance Expectations

- **Transaction save**: < 100ms to IndexedDB
- **Auto-sync trigger**: 2-3 seconds after reconnect
- **Sync per transaction**: 2 seconds (intentional delay for demo)
- **50-item transaction**: < 500ms to save
- **App startup**: 1-2 seconds to initialize IndexedDB

---

## Support

If you get stuck:

1. Check `TESTING.md` for detailed troubleshooting
2. Check `IMPLEMENTATION_SUMMARY.md` for architecture details
3. Check Console logs (filter by `[OfflineDB]`, `[SyncManager]`)
4. Check backend logs (terminal where `node server.js` is running)

---

**Ready to test!** Start with Option 1 (Browser Testing) for quickest results.
