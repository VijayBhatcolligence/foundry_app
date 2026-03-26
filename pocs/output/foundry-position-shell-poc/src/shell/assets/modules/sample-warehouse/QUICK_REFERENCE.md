# 📚 RxDB Quick Reference

**Quick lookup for all RxDB files and their purposes**

---

## File Structure & Purposes

### Configuration Files (src/config/)

| File | Purpose | Key Content |
|------|---------|-------------|
| `database.config.js` | Database settings | DB name, storage type, collections list |
| `api.config.js` | API endpoints | Backend URL, endpoint paths, timeouts |
| `replication.config.js` | Sync settings | Sync interval (1min), batch sizes, conflict strategy |

### Schema Files (src/database/collections/)

| File | Purpose | Exports |
|------|---------|---------|
| `transactions.schema.js` | Transaction data structure | Schema + methods + static methods |
| `waterChecks.schema.js` | Water check data structure | Schema + methods + static methods |
| `complaints.schema.js` | Complaint data structure | Schema + methods + static methods |

**Key Methods on Documents:**
- `softDelete()` - Mark as deleted, queue for sync
- `markSynced()` - Mark sync complete
- `markFailed(error)` - Mark sync failed
- `getDisplayInfo()` - Get formatted display data

**Key Static Methods on Collections:**
- `findPendingSync()` - Get items waiting to sync
- `findPendingDeletes()` - Get deleted items waiting to sync
- `findActive(limit)` - Get non-deleted items

### Database Core (src/database/)

| File | Purpose | Exports |
|------|---------|---------|
| `database.js` | Initialize RxDB | `initialize()`, `getDatabase()`, `closeDatabase()` |

**Usage:**
```javascript
const db = await window.RxDBDatabase.initialize();
const db = window.RxDBDatabase.getDatabase(); // After init
```

### Replication Files (src/database/replication/)

| File | Purpose | Exports |
|------|---------|---------|
| `pull-handler.js` | Download from server | `create(name, endpoint)`, `createAll()` |
| `push-handler.js` | Upload to server | `create(name, endpoint)`, `createAll()` |
| `conflict-handler.js` | Resolve conflicts | `create(name)`, `createSmart(name)`, `createAll()` |
| `replication-setup.js` | Main replication setup | `setup(db)`, `trigger()`, `stop()`, `getStatus()` |

**Usage:**
```javascript
// Setup (called once during init)
await window.RxDBReplication.setup(rxDB);

// Manual sync
await window.RxDBReplication.trigger();

// Check status
const status = window.RxDBReplication.getStatus();
```

### Migration (src/database/migrations/)

| File | Purpose | Exports |
|------|---------|---------|
| `dexie-to-rxdb.js` | Migrate Dexie → RxDB | `migrate(dexie, rxdb)`, `reset()`, `isNeeded()` |

**Usage:**
```javascript
// Check if needed
if (window.RxDBMigration.isNeeded()) {
    const result = await window.RxDBMigration.migrate(dexieDB, rxDB);
}

// Reset (for testing)
window.RxDBMigration.reset();
```

### React Hooks (src/hooks/)

| Hook | Purpose | Returns |
|------|---------|---------|
| `useRxDB()` | Get database instance | `{ db, isInitialized, error }` |
| `useTransactions()` | Transaction CRUD + observable | `{ transactions, loading, error, addTransaction, updateTransaction, deleteTransaction, getTransaction, getPendingCount }` |
| `useWaterChecks()` | Water check CRUD + observable | `{ waterChecks, loading, error, addWaterCheck, deleteWaterCheck }` |
| `useComplaints()` | Complaint CRUD + observable | `{ complaints, loading, error, addComplaint, deleteComplaint }` |
| `useSyncStatus()` | Sync monitoring | `{ isOnline, isSyncing, pendingCounts, lastSyncTime, syncError, triggerSync }` |

---

## Common Operations

### Initialize Database

```javascript
// In app startup
const rxDB = await window.RxDBDatabase.initialize();
```

### Create Transaction

```javascript
const { addTransaction } = window.useTransactions();

await addTransaction({
    poNumber: 'PO-123',
    vendor: 'Acme Corp',
    lineItems: []
});
```

### Delete Transaction (Soft Delete)

```javascript
const { deleteTransaction } = window.useTransactions();

await deleteTransaction('tx-123456');
// Item marked deleted, queued for sync
```

### Subscribe to Updates (Automatic with Hooks!)

```javascript
function MyComponent() {
    // Auto-subscribes to live updates!
    const { transactions } = window.useTransactions();

    // transactions auto-updates when:
    // - New transaction added
    // - Transaction modified
    // - Transaction deleted
    // - Sync downloads new data

    return <div>{transactions.length} transactions</div>;
}
```

### Manual Sync

```javascript
const { triggerSync } = window.useSyncStatus();

const result = await triggerSync();
if (result.success) {
    console.log('Sync complete!');
}
```

### Check Sync Status

```javascript
const { pendingCounts, isOnline, isSyncing } = window.useSyncStatus();

console.log('Pending items:', pendingCounts.total);
console.log('Online:', isOnline);
console.log('Syncing:', isSyncing);
```

---

## Data Flow

### Write Flow (Create/Update/Delete)

```
User Action
    ↓
React Hook (addTransaction, etc.)
    ↓
RxDB Collection (insert/update)
    ↓
┌─────────┴─────────┐
│                   │
IndexedDB      Replication
(Local)        (Push Handler)
    ↓               ↓
Instant UI     Backend API
Update         (when online)
    ↓
Observable emits
    ↓
React Hook receives
    ↓
Component re-renders
```

### Read Flow (Display Data)

```
React Hook subscribes
    ↓
RxDB Observable Query
    ↓
Reads from IndexedDB
    ↓
Emits results
    ↓
React Hook receives
    ↓
Component renders
    ↓
(Any data change → auto re-render!)
```

### Sync Flow (Background)

```
Timer (every 1 min)
    ↓
Replication Triggers
    ↓
┌─────────┴─────────┐
│                   │
PULL            PUSH
(Download)      (Upload)
    ↓               ↓
Backend API     Backend API
    ↓               ↓
Transform       Transform
    ↓               ↓
RxDB merge      Mark synced
    ↓
Observable emits
    ↓
UI auto-updates
```

---

## Configuration Quick Tweaks

### Change Sync Interval

**File:** `src/config/replication.config.js`
```javascript
syncInterval: 60 * 1000, // 60 seconds = 1 minute
// Change to 30 * 1000 for 30 seconds
```

### Change Batch Size

**File:** `src/config/replication.config.js`
```javascript
batchSize: 50, // Sync 50 items at a time
// Increase to 100 for faster sync of large datasets
```

### Change Conflict Strategy

**File:** `src/database/replication/replication-setup.js`
```javascript
const conflictHandlers = window.RxDBConflictHandler.createAll(false);
// Change to true for smart merge strategy
```

### Change API Endpoint

**File:** `src/config/api.config.js`
```javascript
baseURL: 'http://192.168.0.163:3000',
// Change to your server address
```

---

## Debugging

### Enable Verbose Logging

**Browser Console:**
```javascript
// Enable RxDB dev mode
RxDB.plugin(RxDBDevModePlugin);

// All operations will log details
```

### Check Database State

```javascript
const db = window.RxDBDatabase.getDatabase();

// Count documents
const txCount = await db.transactions.count().exec();
const wcCount = await db.waterChecks.count().exec();
console.log('Transactions:', txCount, 'Water Checks:', wcCount);

// Get all documents
const allTx = await db.transactions.find().exec();
console.log('All transactions:', allTx);
```

### Check Replication Status

```javascript
const status = window.RxDBReplication.getStatus();
console.log('Replication status:', status);
```

### Force Sync

```javascript
// Manual trigger
await window.RxDBReplication.trigger();

// Check if it worked
const { pendingCounts } = window.useSyncStatus();
console.log('Pending after sync:', pendingCounts);
```

---

## Common Issues & Solutions

| Issue | Solution |
|-------|----------|
| UI not updating | Use React hooks, they handle observables |
| Sync not working | Check `navigator.onLine`, backend URL, CORS |
| Migration failed | Check console logs, verify Dexie data exists |
| Conflicts not resolved | Check conflict handler, ensure timestamps set |
| Data not persisting | Check IndexedDB quota, clear if full |

---

## Performance Tips

1. **Limit query results:**
   ```javascript
   .find().limit(100) // Don't load 1000s at once
   ```

2. **Use indexes:**
   Schemas already have indexes on:
   - `syncStatus`
   - `createdAt`
   - `deleted`

3. **Batch operations:**
   ```javascript
   await db.transactions.bulkInsert([...]); // Faster than individual inserts
   ```

4. **Avoid nested subscriptions:**
   Use React hooks - they handle this for you!

---

## Key Takeaways

✅ **React Hooks** handle all database operations + observables
✅ **Replication** is automatic (every 1 min + on connectivity change)
✅ **Soft deletes** sync properly (deleted: true)
✅ **Conflicts** resolve automatically (last-write-wins)
✅ **Local-first** - UI updates instantly, syncs in background

**Main Integration File:** `RXDB_INTEGRATION_GUIDE.md`
