# Quick Code Changes for index.html

## 🔄 Find & Replace Operations

Use your text editor's find & replace to quickly update the code:

### 1. Replace Database Reference

**Find:**
```javascript
offlineDB
```

**Replace with:**
```javascript
rxdbRef.current
```

---

### 2. Replace Insert Operations

**Find:**
```javascript
.add(
```

**Replace with:**
```javascript
.insert(
```

---

### 3. Replace Collection Names (lowercase!)

**Find:**
```javascript
waterChecks
```

**Replace with:**
```javascript
waterchecks
```

**Note:** RxDB uses lowercase collection names!

---

## 📝 Specific Code Changes

### Change 1: Import Statements (Add at top of script)

**Add after React imports:**
```javascript
import { initDatabase } from './db/schema.js';
import { SyncManager } from './sync/SyncManager.js';
```

---

### Change 2: Remove Dexie Initialization

**REMOVE entire block (around line 610-625):**
```javascript
// ❌ DELETE THIS
offlineDB = new Dexie('warehouse_offline_db');
offlineDB.version(3).stores({
    transactions: '&transactionId, syncStatus, createdAt, poNumber',
    waterChecks: '&id, syncStatus, createdAt, product',
    complaints: '&id, syncStatus, createdAt, product'
});
await offlineDB.open();
console.log('[OfflineDB] Database created with Dexie');
```

**REPLACE with:**
```javascript
// ✅ ADD THIS
const database = await initDatabase();
console.log('[OfflineDB] RxDB initialized successfully');
return database;
```

---

### Change 3: Remove Inline SyncManager Class

**REMOVE entire SyncManager class (around lines 630-1100):**
```javascript
// ❌ DELETE ENTIRE CLASS
class SyncManager {
    constructor(db, isOnline) {
        // ... hundreds of lines ...
    }
}
```

**It's now imported from `/sync/SyncManager.js`!**

---

### Change 4: Update React Refs

**Find:**
```javascript
const offlineDBRef = React.useRef(null);
```

**Replace with:**
```javascript
const rxdbRef = React.useRef(null);
```

---

### Change 5: Update Database Initialization in useEffect

**Find:**
```javascript
const initDB = async () => {
    try {
        console.log('[App] Initializing offline database...');
        const db = await initOfflineDB();
        offlineDBRef.current = db;

        const syncMgr = new SyncManager(db, navigator.onLine);
        syncManagerRef.current = syncMgr;
        // ...
```

**Replace with:**
```javascript
const initDB = async () => {
    try {
        console.log('[App] Initializing offline database...');
        const db = await initOfflineDB();
        rxdbRef.current = db;  // Changed

        const syncMgr = new SyncManager(db);  // Removed navigator.onLine param
        syncManagerRef.current = syncMgr;
        // ...
```

---

### Change 6: Update Insert Operations

**OLD (Dexie):**
```javascript
await offlineDB.transactions.add(transactionData);
await offlineDB.waterChecks.add(waterCheckData);
await offlineDB.complaints.add(complaintData);
```

**NEW (RxDB):**
```javascript
await rxdbRef.current.transactions.insert(transactionData);
await rxdbRef.current.waterchecks.insert(waterCheckData);  // lowercase!
await rxdbRef.current.complaints.insert(complaintData);
```

---

### Change 7: Update Load History Functions

**OLD (Dexie):**
```javascript
const loadTransactionsHistory = async () => {
    const history = await offlineDB.transactions.toArray();
    setPendingTransactions(history);
};
```

**NEW (RxDB):**
```javascript
const loadTransactionsHistory = async () => {
    const docsQuery = await rxdbRef.current.transactions
        .find({ sort: [{ createdAt: 'desc' }] })
        .exec();
    const history = docsQuery.map(doc => doc.toJSON());
    setPendingTransactions(history);
};
```

---

### Change 8: Update Query with Filter

**OLD (Dexie):**
```javascript
const pending = await offlineDB.transactions
    .where('syncStatus')
    .equals('pending')
    .sortBy('createdAt');
```

**NEW (RxDB):**
```javascript
const pendingQuery = await rxdbRef.current.transactions
    .find({
        selector: { syncStatus: 'pending' },
        sort: [{ createdAt: 'asc' }]
    })
    .exec();
const pending = pendingQuery.map(doc => doc.toJSON());
```

---

### Change 9: Update Count Operations

**OLD (Dexie):**
```javascript
const count = await offlineDB.transactions.count();
```

**NEW (RxDB):**
```javascript
const countQuery = await rxdbRef.current.transactions.count().exec();
const count = countQuery;
```

---

### Change 10: Update Delete Operations

**OLD (Dexie):**
```javascript
await offlineDB.transactions.delete(transactionId);
```

**NEW (RxDB):**
```javascript
const doc = await rxdbRef.current.transactions.findOne(transactionId).exec();
if (doc) {
    await doc.remove();
}
```

---

## 🎯 Complete Example: Save Transaction

### BEFORE (Dexie):
```javascript
const handleSubmit = async () => {
    const transactionData = {
        transactionId: `TXN-${Date.now()}`,
        poNumber: transaction.poNumber,
        vendor: transaction.vendor,
        lineItems: transaction.lineItems,
        createdAt: Date.now(),
        syncStatus: 'pending',
        retryCount: 0,
        lastError: null,
        lastSyncAttempt: null
    };

    if (dbReady && offlineDB) {
        await offlineDB.transactions.add(transactionData);
        console.log('[App] Transaction saved to IndexedDB');

        if (networkOnline && syncManagerRef.current) {
            setTimeout(() => {
                syncManagerRef.current.syncPendingTransactions();
            }, 500);
        }
    }
};
```

### AFTER (RxDB):
```javascript
const handleSubmit = async () => {
    const transactionData = {
        transactionId: `TXN-${Date.now()}`,
        poNumber: transaction.poNumber,
        vendor: transaction.vendor,
        lineItems: transaction.lineItems,
        createdAt: Date.now(),
        syncStatus: 'pending',
        retryCount: 0,
        lastError: null,
        lastSyncAttempt: null
    };

    if (dbReady && rxdbRef.current) {  // Changed
        await rxdbRef.current.transactions.insert(transactionData);  // Changed
        console.log('[App] Transaction saved to RxDB');  // Changed

        if (networkOnline && syncManagerRef.current) {
            setTimeout(() => {
                syncManagerRef.current.syncPendingTransactions();
            }, 500);
        }
    }
};
```

---

## ✅ Testing After Changes

1. **Check Console:**
   ```
   [OfflineDB] Initializing RxDB database...
   [Database] RxDB database created
   [Database] Collections added (transactions, waterchecks, complaints)
   [SyncManager] Initialized. Online: true
   ```

2. **Check DevTools → Application → IndexedDB:**
   - Database: `warehouse_offline_db`
   - Collections: `transactions`, `waterchecks`, `complaints`

3. **Test Offline:**
   - Turn off network
   - Submit transaction → Should save locally
   - Turn on network → Should auto-sync

4. **Check Sync Logs:**
   ```
   [SyncManager] Starting sync...
   [SyncManager] Found X pending transactions
   [SyncManager] Syncing transaction TXN-123...
   [SyncManager] Transaction TXN-123 synced successfully
   ```

---

## 🚨 Common Errors & Fixes

### Error: "Cannot read property 'transactions' of null"
**Fix:** Make sure `rxdbRef.current` is initialized before using it.

### Error: "waterchecks is not a function"
**Fix:** Change `waterChecks` to `waterchecks` (lowercase!)

### Error: "Cannot find module './db/schema.js'"
**Fix:** Check import path is correct relative to index.html location.

### Error: ".add is not a function"
**Fix:** Use `.insert()` instead of `.add()` for RxDB.

### Error: ".toArray is not a function"
**Fix:** Use `.find().exec()` then `.map(doc => doc.toJSON())` for RxDB.

---

## 📞 Need Help?

If you get stuck:
1. Check browser console for errors
2. Verify imports are correct
3. Ensure all Dexie code is removed
4. Check collection names are lowercase
5. Verify RxDB query syntax
