# RxDB Migration Guide

## ✅ Completed Steps

1. **Extended RxDB Schema** (`/db/schema.js`)
   - ✅ Added `waterCheckSchema` for water temperature checks
   - ✅ Added `complaintSchema` for quality complaints
   - ✅ Updated database initialization to create all 3 collections

2. **Extended SyncManager** (`/sync/SyncManager.js`)
   - ✅ Added `syncPendingWaterChecks()` method
   - ✅ Added `syncPendingComplaints()` method
   - ✅ Updated connectivity handlers to sync all types
   - ✅ Updated `getSyncStatus()` to return status for all types
   - ✅ Updated `forceSyncNow()` to sync all types

## 🔧 Required Changes in index.html

### Step 1: Remove Dexie Implementation

**Find and REMOVE these lines (around line 565-625):**

```javascript
let offlineDB = null;
let syncManager = null;

// ... all the Dexie initialization code ...

offlineDB = new Dexie('warehouse_offline_db');
offlineDB.version(3).stores({
    transactions: '&transactionId, syncStatus, createdAt, poNumber',
    waterChecks: '&id, syncStatus, createdAt, product',
    complaints: '&id, syncStatus, createdAt, product'
});
await offlineDB.open();
```

**REMOVE the entire inline SyncManager class (around lines 630-1100):**
- The class that starts with `class SyncManager {`
- Everything until the closing `}`

### Step 2: Import RxDB Modules

**Add at the top of your script section (after React imports):**

```javascript
// Import RxDB database and sync manager
import { initDatabase } from './db/schema.js';
import { SyncManager } from './sync/SyncManager.js';
```

### Step 3: Update Database Initialization

**Replace the `initOfflineDB()` function with:**

```javascript
async function initOfflineDB() {
    try {
        console.log('[OfflineDB] Initializing RxDB database...');

        // Initialize RxDB (creates transactions, waterchecks, complaints collections)
        const database = await initDatabase();
        console.log('[OfflineDB] RxDB initialized successfully');

        return database;
    } catch (error) {
        console.error('[OfflineDB] Failed to initialize RxDB:', error);
        throw error;
    }
}
```

### Step 4: Update React Component State

**In your main App component, replace:**

```javascript
const [dbReady, setDbReady] = useState(false);
const offlineDBRef = React.useRef(null);
const syncManagerRef = React.useRef(null);
```

**With:**

```javascript
const [dbReady, setDbReady] = useState(false);
const rxdbRef = React.useRef(null);  // Changed from offlineDBRef
const syncManagerRef = React.useRef(null);
```

### Step 5: Update Database Initialization in useEffect

**Replace the database initialization code with:**

```javascript
React.useEffect(() => {
    const initDB = async () => {
        try {
            console.log('[App] Initializing offline database...');

            // Initialize RxDB
            const db = await initOfflineDB();
            rxdbRef.current = db;

            // Initialize SyncManager with RxDB instance
            const syncMgr = new SyncManager(db);
            syncManagerRef.current = syncMgr;

            setDbReady(true);
            console.log('[App] Offline database ready');

        } catch (err) {
            console.error('[App] Failed to initialize database:', err);
            setBackendStatus('error');
        }
    };

    initDB();
}, []);
```

### Step 6: Update All Database Operations

**Replace ALL Dexie operations with RxDB operations:**

#### Transactions:

**OLD (Dexie):**
```javascript
await offlineDB.transactions.add(transactionData);
const pending = await offlineDB.transactions.where('syncStatus').equals('pending').toArray();
```

**NEW (RxDB):**
```javascript
await rxdbRef.current.transactions.insert(transactionData);
const pending = await rxdbRef.current.transactions
    .find({ selector: { syncStatus: 'pending' } })
    .exec();
```

#### Water Checks:

**OLD (Dexie):**
```javascript
await offlineDB.waterChecks.add(waterCheckData);
const checks = await offlineDB.waterChecks.toArray();
```

**NEW (RxDB):**
```javascript
await rxdbRef.current.waterchecks.insert(waterCheckData);
const checks = await rxdbRef.current.waterchecks.find().exec();
```

#### Complaints:

**OLD (Dexie):**
```javascript
await offlineDB.complaints.add(complaintData);
const complaints = await offlineDB.complaints.toArray();
```

**NEW (RxDB):**
```javascript
await rxdbRef.current.complaints.insert(complaintData);
const complaints = await rxdbRef.current.complaints.find().exec();
```

### Step 7: Update Query Operations

**OLD (Dexie):**
```javascript
// Get all water checks
const checks = await offlineDB.waterChecks.toArray();

// Get by sync status
const pending = await offlineDB.waterChecks
    .where('syncStatus')
    .equals('pending')
    .sortBy('createdAt');

// Update record
await offlineDB.waterChecks.update(id, { syncStatus: 'synced' });
```

**NEW (RxDB):**
```javascript
// Get all water checks
const checksQuery = await rxdbRef.current.waterchecks.find().exec();
const checks = checksQuery.map(doc => doc.toJSON());

// Get by sync status with sorting
const pendingQuery = await rxdbRef.current.waterchecks
    .find({
        selector: { syncStatus: 'pending' },
        sort: [{ createdAt: 'asc' }]
    })
    .exec();

// Update record
const doc = await rxdbRef.current.waterchecks.findOne(id).exec();
await doc.update({
    $set: { syncStatus: 'synced' }
});
```

### Step 8: Update Load History Functions

**Replace `loadTransactionsHistory()`, `loadWaterTempHistory()`, `loadComplaintsHistory()` with RxDB queries:**

```javascript
const loadTransactionsHistory = async () => {
    try {
        console.log('[LocalDB] Loading transaction history from RxDB...');

        const docsQuery = await rxdbRef.current.transactions
            .find({ sort: [{ createdAt: 'desc' }] })
            .exec();

        const history = docsQuery.map(doc => doc.toJSON());

        console.log(`[LocalDB] ✅ Loaded ${history.length} transactions from RxDB`);
        setPendingTransactions(history);

    } catch (err) {
        console.error('[LocalDB] Failed to load from RxDB:', err);
    }
};

const loadWaterTempHistory = async () => {
    try {
        console.log('[LocalDB] Loading water temp history from RxDB...');

        const docsQuery = await rxdbRef.current.waterchecks
            .find({ sort: [{ createdAt: 'desc' }] })
            .exec();

        const history = docsQuery.map(doc => doc.toJSON());

        console.log(`[LocalDB] ✅ Loaded ${history.length} water checks from RxDB`);
        setWaterCheckHistory(history);

    } catch (err) {
        console.error('[LocalDB] Failed to load water checks:', err);
    }
};

const loadComplaintsHistory = async () => {
    try {
        console.log('[LocalDB] Loading complaints history from RxDB...');

        const docsQuery = await rxdbRef.current.complaints
            .find({ sort: [{ createdAt: 'desc' }] })
            .exec();

        const history = docsQuery.map(doc => doc.toJSON());

        console.log(`[LocalDB] ✅ Loaded ${history.length} complaints from RxDB`);
        setComplaintsHistory(history);

    } catch (err) {
        console.error('[LocalDB] Failed to load complaints:', err);
    }
};
```

### Step 9: Update Sync Trigger Calls

**Replace all sync trigger calls:**

**OLD:**
```javascript
syncManagerRef.current.syncPendingTransactions();
syncManagerRef.current.syncPendingWaterChecks();
syncManagerRef.current.syncPendingComplaints();
```

**NEW (same, but now uses RxDB SyncManager):**
```javascript
syncManagerRef.current.syncPendingTransactions();
syncManagerRef.current.syncPendingWaterChecks();
syncManagerRef.current.syncPendingComplaints();
```

### Step 10: Update Manual Sync Button

**The manual sync button should now sync all types:**

```javascript
const handleManualSync = async () => {
    if (syncManagerRef.current) {
        console.log('[App] Manual sync triggered - syncing all types');
        await syncManagerRef.current.forceSyncNow();

        // Reload all histories
        await loadTransactionsHistory();
        await loadWaterTempHistory();
        await loadComplaintsHistory();
    }
};
```

## 🎯 Key Differences: Dexie vs RxDB

| Operation | Dexie | RxDB |
|-----------|-------|------|
| **Add record** | `.add(data)` | `.insert(data)` |
| **Get all** | `.toArray()` | `.find().exec()` then `.map(doc => doc.toJSON())` |
| **Query** | `.where('field').equals(value)` | `.find({ selector: { field: value } }).exec()` |
| **Update** | `.update(id, changes)` | Find doc, then `doc.update({ $set: changes })` |
| **Delete** | `.delete(id)` | Find doc, then `doc.remove()` |
| **Sort** | `.sortBy('field')` | `.find({ sort: [{ field: 'asc' }] })` |

## ✅ Testing Checklist

After migration, test:

1. ✅ Database initialization on app load
2. ✅ Save transaction offline
3. ✅ Save water check offline
4. ✅ Save complaint offline
5. ✅ Auto-sync when coming online
6. ✅ Manual sync button
7. ✅ Load history for all three types
8. ✅ Check browser DevTools → Application → IndexedDB for `warehouse_offline_db`

## 🚀 Expected Console Logs

```
[OfflineDB] Initializing RxDB database...
[Database] Initializing RxDB database...
[Database] RxDB database created
[Database] Collections added (transactions, waterchecks, complaints)
[Database] Database initialized successfully
[OfflineDB] RxDB initialized successfully
[SyncManager] Initialized. Online: true
[App] Offline database ready
```

## 📝 Notes

- RxDB uses **observables** - you can subscribe to changes with `.find().$.subscribe()`
- RxDB documents are **immutable** - use `.update()` or `.atomicUpdate()` to modify
- RxDB has better **TypeScript support** than Dexie
- RxDB is **more powerful** for complex queries and replication

## ❓ Need Help?

If you encounter errors, check:
1. Import paths are correct (./db/schema.js, ./sync/SyncManager.js)
2. All Dexie code is removed
3. Collection names match: `transactions`, `waterchecks`, `complaints` (lowercase!)
4. Using RxDB query syntax (not Dexie syntax)
