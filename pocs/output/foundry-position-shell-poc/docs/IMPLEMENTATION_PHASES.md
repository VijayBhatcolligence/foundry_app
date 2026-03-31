# 🚀 HYBRID ARCHITECTURE IMPLEMENTATION - ALL PHASES

**Project**: Foundry Position Shell - Hybrid Storage Architecture
**Goal**: Implement reliable offline-capable architecture with Flutter SQLite (source of truth) + IndexedDB (reference cache)
**Total Duration**: 39-51 hours (5-7 days)
**Starting Point**: Existing code at `foundry-position-shell-poc/src`

---

## 📊 PHASES OVERVIEW

| Phase | Duration | What Gets Built | Key Milestone |
|-------|----------|-----------------|---------------|
| 0 | 2-3h | Documentation & Architecture | Foundation documented |
| 1 | 3-4h | Local HTTP Server (Flutter) | Stable origin achieved |
| 2 | 4-5h | SQLite Action Queue (Flutter) | Source of truth storage |
| 3 | 2-3h | Backend API Endpoints | Test APIs ready |
| 4 | 5-6h | Test Module 1 - Inventory Checker | First test module working |
| 5 | 5-6h | Test Module 2 - Quality Inspector | Second test module working |
| 6 | 3-4h | Reference Data Manager | Reusable component |
| 7 | 4-5h | Sync Manager | Queue processing works |
| 8 | 3-4h | Integration Testing | E2E validation complete |
| 9 | 6-8h | Rebuild sample-warehouse | Production module ready |
| 10 | 2-3h | Final Validation | Deployment ready |

---

# PHASE 0: DOCUMENTATION & ARCHITECTURE FOUNDATION

**Duration**: 2-3 hours
**Type**: Documentation & Planning

## Current State
- Existing Flutter shell with WebView
- Modules load from `file://` protocol
- sample-warehouse using RxDB/IndexedDB
- Existing bridges: scanner, photo, connectivity
- Backend server running on port 3000

## What Will Be Implemented

### 1. Architecture Documentation
**File**: `docs/HYBRID_ARCHITECTURE.md`

**Contents**:
- Storage strategy explanation (SQLite vs IndexedDB)
- Data flow diagrams:
  - React → creates action → Flutter SQLite (source of truth)
  - React Sync Manager → reads SQLite → syncs to Backend
  - React Reference Manager → fetches backend → stores in IndexedDB
- Component responsibilities
- Read vs Write path rules

### 2. Database Schema Design
**File**: `docs/SCHEMAS.md`

**SQLite Schema** (Flutter):
```sql
CREATE TABLE action_queue (
  id TEXT PRIMARY KEY,
  module_id TEXT NOT NULL,
  action_type TEXT NOT NULL,
  payload TEXT NOT NULL,
  status TEXT DEFAULT 'pending',
  retry_count INTEGER DEFAULT 0,
  error_message TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

CREATE INDEX idx_module_status ON action_queue(module_id, status);
CREATE INDEX idx_pending ON action_queue(status) WHERE status='pending';
```

**IndexedDB Schema** (React per module):
```javascript
// Store: reference_data
{
  key: 'products',      // or 'customers', 'vendors'
  value: [...],         // Array of data
  version: '1.0',
  updated_at: timestamp,
  expires_at: timestamp // 24h expiry
}
```

### 3. Folder Structure Planning
**File**: `docs/FOLDER_STRUCTURE.md`

```
src/
├── backend/ (existing - will extend)
│   └── server.js (add 6 new endpoints)
│
├── shell/
│   ├── lib/
│   │   ├── storage/                    ← NEW FOLDER
│   │   │   ├── local_http_server.dart  ← Phase 1
│   │   │   └── action_queue_db.dart    ← Phase 2
│   │   │
│   │   └── bridge/
│   │       └── shell_bridge.dart (modify - add SQLite methods)
│   │
│   └── assets/modules/
│       ├── sample-warehouse/           ← DELETE in Phase 9
│       ├── test-inventory-checker/     ← Phase 4
│       ├── test-quality-inspector/     ← Phase 5
│       └── sample-warehouse-new/       ← Phase 9
```

### 4. Modification Plan Per Phase
**File**: `docs/MODIFICATION_ROADMAP.md`

Lists for each phase:
- Files to create
- Files to modify
- Files to delete
- Dependencies on previous phases

## Success Criteria

✅ Architecture document complete with diagrams
✅ Database schemas designed and documented
✅ Folder structure planned
✅ Storage rules clearly defined (SQLite = critical, IndexedDB = cache)
✅ Data flow understood (React → Flutter → Backend)
✅ Team reviewed and approved approach

## Deliverables

1. `docs/HYBRID_ARCHITECTURE.md` - Full architecture explanation
2. `docs/SCHEMAS.md` - Database schemas
3. `docs/FOLDER_STRUCTURE.md` - File organization plan
4. `docs/MODIFICATION_ROADMAP.md` - Phase-by-phase changes

## Testing Approach
None (documentation phase)

---

# PHASE 1: LOCAL HTTP SERVER

**Duration**: 3-4 hours
**Type**: Flutter Infrastructure

## Current State
- Modules load from `file://assets/modules/...`
- WebView origin is `null` or `file://`
- IndexedDB unreliable due to unstable origin

## What Will Be Implemented

### 1. Add Dependencies
**File**: `src/shell/pubspec.yaml` (MODIFY)

Add:
```yaml
dependencies:
  shelf: ^1.4.1
  shelf_static: ^1.1.2
```

### 2. Create LocalHttpServer Class
**File**: `src/shell/lib/storage/local_http_server.dart` (NEW)

**Responsibilities**:
- Start HTTP server on app launch
- Allocate port (8080 or find available)
- Copy module assets to accessible temp directory
- Serve modules from `http://localhost:PORT/module-id/`
- Handle CORS for backend API calls
- Manage server lifecycle (start/stop/pause/resume)

**Key Methods**:
- `Future<void> start()` - Initialize and start server
- `Future<void> stop()` - Stop server on app termination
- `int? get port` - Get allocated port
- `String? get baseUrl` - Get base URL (http://localhost:PORT)

### 3. Integrate with Main App
**File**: `src/shell/lib/main.dart` (MODIFY)

**Changes**:
- Import LocalHttpServer
- Create server instance in app state
- Start server in initState
- Update WebView loading:
  - OLD: `webViewController.loadFlutterAsset('assets/modules/...')`
  - NEW: `webViewController.loadUrl('http://localhost:8080/module-id/')`

### 4. Update Module Loading Logic
**File**: `src/shell/lib/modules/module_registry.dart` (MODIFY)

**Changes**:
- Update module loading to use localhost URLs
- Pass base URL from LocalHttpServer
- Ensure module paths map correctly

## Files Created/Modified

**NEW**:
- `lib/storage/local_http_server.dart`

**MODIFIED**:
- `pubspec.yaml` (add dependencies)
- `lib/main.dart` (integrate server)
- `lib/modules/module_registry.dart` (update loading)

## Success Criteria

✅ Server starts successfully on app launch
✅ Console shows: `[LocalHttpServer] Server started on port: 8080`
✅ Modules load from `http://localhost:8080/module-id/`
✅ WebView DevTools shows `window.location.origin = "http://localhost:8080"`
✅ Origin is NOT `null` or `file://`
✅ Server survives app pause/resume
✅ No CORS errors when calling backend

## Testing Approach

**Manual Test**:
1. Run app
2. Check console for server startup logs
3. Open WebView DevTools (Chrome inspect)
4. Run: `console.log(window.location.origin)`
5. Expected: `"http://localhost:8080"`
6. Pause app, resume → verify server still works

**Automated Test**:
```dart
test('LocalHttpServer starts and serves content', () async {
  final server = LocalHttpServer();
  await server.start();

  expect(server.port, isNotNull);
  expect(server.baseUrl, startsWith('http://localhost:'));

  // Test HTTP request
  final response = await http.get(Uri.parse('${server.baseUrl}/test'));
  expect(response.statusCode, anyOf([200, 404]));
});
```

## Deliverables

- ✅ LocalHttpServer class working
- ✅ Stable localhost origin confirmed
- ✅ Console logs showing server status
- ✅ Test results documented

---

# PHASE 2: SQLITE ACTION QUEUE (SOURCE OF TRUTH)

**Duration**: 4-5 hours
**Type**: Flutter Storage Layer

## Current State
- No Flutter-side SQLite for action queue
- All data in WebView IndexedDB
- No bridge for critical data storage

## What Will Be Implemented

### 1. Add SQLite Dependency
**File**: `src/shell/pubspec.yaml` (MODIFY)

Add (if not already present):
```yaml
dependencies:
  sqflite: ^2.3.0
```

### 2. Create ActionQueueDB Class
**File**: `src/shell/lib/storage/action_queue_db.dart` (NEW)

**Responsibilities**:
- Initialize SQLite database on app start
- Create action_queue table with indexes
- Provide CRUD methods for actions
- Filter actions by module_id and status
- Update action status (pending → syncing → synced → error)

**Key Methods**:
- `Future<void> initialize()` - Setup database
- `Future<String> saveAction(Map<String, dynamic> action)` - Save new action
- `Future<List<Map>> getActions(String moduleId, String status)` - Query actions
- `Future<bool> updateActionStatus(String id, String status, [String? error])` - Update status
- `Future<bool> deleteAction(String id)` - Delete action
- `Future<int> getPendingCount(String moduleId)` - Count pending actions

### 3. Add Bridge Methods
**File**: `src/shell/lib/bridge/shell_bridge.dart` (MODIFY)

**Add to existing bridge handler**:
```dart
case 'saveAction':
  final result = await actionQueueDB.saveAction(arguments);
  return {'success': true, 'id': result};

case 'getActions':
  final actions = await actionQueueDB.getActions(
    arguments['moduleId'],
    arguments['status'] ?? 'pending'
  );
  return {'success': true, 'actions': actions};

case 'updateActionStatus':
  await actionQueueDB.updateActionStatus(
    arguments['id'],
    arguments['status'],
    arguments['error']
  );
  return {'success': true};

case 'deleteAction':
  await actionQueueDB.deleteAction(arguments['id']);
  return {'success': true};

case 'getPendingCount':
  final count = await actionQueueDB.getPendingCount(arguments['moduleId']);
  return {'success': true, 'count': count};
```

### 4. Create JavaScript Bridge Helper
**File**: `src/shell/assets/bridge_helper.js` (NEW)

**Shared utility for React modules**:
```javascript
window.ActionQueue = {
  async save(moduleId, actionType, payload) {
    const result = await window.shellBridge.call('saveAction', {
      id: generateUUID(),
      module_id: moduleId,
      action_type: actionType,
      payload: JSON.stringify(payload),
      status: 'pending',
      retry_count: 0,
      created_at: Date.now(),
      updated_at: Date.now()
    });
    return result;
  },

  async getPending(moduleId) {
    const result = await window.shellBridge.call('getActions', {
      moduleId: moduleId,
      status: 'pending'
    });
    return result.actions;
  },

  async markSynced(id) {
    return await window.shellBridge.call('updateActionStatus', {
      id: id,
      status: 'synced'
    });
  },

  async markError(id, error) {
    return await window.shellBridge.call('updateActionStatus', {
      id: id,
      status: 'error',
      error: error
    });
  }
};
```

### 5. Initialize in Main App
**File**: `src/shell/lib/main.dart` (MODIFY)

**Add**:
- Initialize ActionQueueDB in app startup
- Pass to ShellBridge

## Files Created/Modified

**NEW**:
- `lib/storage/action_queue_db.dart`
- `assets/bridge_helper.js`

**MODIFIED**:
- `pubspec.yaml` (ensure sqflite dependency)
- `lib/bridge/shell_bridge.dart` (add bridge methods)
- `lib/main.dart` (initialize database)

## Success Criteria

✅ SQLite database creates successfully on app start
✅ action_queue table and indexes created
✅ Bridge methods work from React (can call from JavaScript)
✅ Actions save to Flutter SQLite
✅ Actions can be retrieved by module_id + status
✅ Status updates work (pending → synced)
✅ Data persists across app restart
✅ Data persists across phone restart
✅ Multiple modules have isolated queues (filtered by module_id)

## Testing Approach

**Manual Test**:
1. Load app, check console for database initialization
2. Open WebView DevTools
3. Test bridge from console:
   ```javascript
   await window.ActionQueue.save('test-module', 'test_action', {data: 'test'});
   const actions = await window.ActionQueue.getPending('test-module');
   console.log(actions);
   ```
4. Close app completely
5. Reopen app
6. Verify action still exists

**Automated Test**:
```dart
test('Action queue CRUD operations', () async {
  final db = ActionQueueDB();
  await db.initialize();

  // Save
  final id = await db.saveAction({
    'id': 'test-001',
    'module_id': 'test-module',
    'action_type': 'transaction',
    'payload': '{"test": true}',
    'status': 'pending',
    'created_at': DateTime.now().millisecondsSinceEpoch,
  });
  expect(id, equals('test-001'));

  // Retrieve
  final actions = await db.getActions('test-module', 'pending');
  expect(actions.length, equals(1));

  // Update
  await db.updateActionStatus('test-001', 'synced');
  final updated = await db.getActions('test-module', 'synced');
  expect(updated.length, equals(1));
});
```

## Deliverables

- ✅ SQLite database working
- ✅ Bridge methods functional
- ✅ Persistence verified
- ✅ Test results documented

---

# PHASE 3: BACKEND API ENDPOINTS

**Duration**: 2-3 hours
**Type**: Backend Extension

## Current State
- Backend has endpoints for sample-warehouse:
  - `/api/transactions`
  - `/api/water-temp`
  - `/api/complaints`
  - `/api/products/:barcode`

## What Will Be Implemented

### Add 6 New Endpoints
**File**: `src/backend/server.js` (MODIFY)

**New Endpoints**:

1. **GET /api/products** - Product search (Inventory Checker)
   - Query param: `?q=search_term`
   - Returns: Array of products matching search

2. **POST /api/stock-counts** - Stock count submission (Inventory Checker)
   - Body: `{sku, quantity, location, timestamp}`
   - Returns: Success confirmation

3. **POST /api/audit-trail** - Audit trail submission (Inventory Checker)
   - Body: `{action, notes, timestamp}`
   - Returns: Success confirmation

4. **GET /api/defects/:code** - Defect lookup (Quality Inspector)
   - Param: defect code
   - Returns: Defect details

5. **POST /api/inspection-logs** - Inspection log submission (Quality Inspector)
   - Body: `{product, result, notes, timestamp}`
   - Returns: Success confirmation

6. **POST /api/reports** - Report submission (Quality Inspector)
   - Body: `{report_type, data, timestamp}`
   - Returns: Success confirmation

## Files Created/Modified

**MODIFIED**:
- `src/backend/server.js` (add 6 endpoints)

## Success Criteria

✅ All 6 endpoints added to server.js
✅ Backend starts without errors
✅ Endpoints return correct HTTP status codes:
  - 200 for successful GET
  - 201 for successful POST
  - 400 for validation errors
  - 404 for not found
✅ Request/response logging works
✅ CORS headers allow WebView requests
✅ Validation errors return clear messages

## Testing Approach

**Manual Test with curl**:
```bash
# Test product search
curl http://localhost:3000/api/products?q=Widget

# Test stock count
curl -X POST http://localhost:3000/api/stock-counts \
  -H "Content-Type: application/json" \
  -d '{"sku":"ABC-001","quantity":50,"location":"A1"}'

# Test defect lookup
curl http://localhost:3000/api/defects/D001
```

**Automated Test**:
```javascript
// test/backend_api_test.js
describe('New API Endpoints', () => {
  test('Product search works', async () => {
    const res = await axios.get('http://localhost:3000/api/products?q=Widget');
    expect(res.status).toBe(200);
    expect(res.data.success).toBe(true);
  });

  test('Stock count submission works', async () => {
    const res = await axios.post('http://localhost:3000/api/stock-counts', {
      sku: 'ABC-001',
      quantity: 50,
      location: 'A1'
    });
    expect(res.status).toBe(201);
  });
});
```

## Deliverables

- ✅ 6 new endpoints implemented
- ✅ Backend test script passes
- ✅ API documentation updated

---

# PHASE 4: TEST MODULE 1 - INVENTORY CHECKER

**Duration**: 5-6 hours
**Type**: React Module Development

## Current State
- No test modules exist yet
- sample-warehouse will be deleted later

## What Will Be Implemented

### 1. Module Structure
**Location**: `src/shell/assets/modules/test-inventory-checker/`

**Files to Create**:
```
test-inventory-checker/
├── package.json              (webpack, react, idb dependencies)
├── webpack.config.js         (build configuration)
├── public/
│   └── index.html
├── src/
│   ├── index.js              (entry point)
│   ├── App.jsx               (main component)
│   ├── components/
│   │   ├── Feature1_ProductSearch.jsx      (online only)
│   │   ├── Feature2_StockCount.jsx         (IndexedDB)
│   │   └── Feature3_AuditTrail.jsx         (SQLite bridge)
│   └── utils/
│       ├── indexedDBHelper.js              (IndexedDB utilities)
│       └── actionQueueHelper.js            (SQLite bridge helper)
└── dist/                     (build output - will be served)
```

### 2. Three Features

**Feature 1: Product Search (Online Only)**
- Input field for search term
- Button to search
- Makes API call to GET /api/products
- Displays results
- No local storage

**Feature 2: Stock Count (IndexedDB - Expendable)**
- Form: SKU, Quantity, Location
- Save button → stores in IndexedDB
- List view showing saved stock counts
- Clear button to delete all
- Data can be lost, not critical

**Feature 3: Audit Trail (SQLite Bridge - Critical)**
- Form: Action, Notes, Timestamp
- Save button → calls Flutter bridge → stores in SQLite
- List view showing saved audit trails (read from SQLite)
- Clear button (deletes from SQLite)
- Data CANNOT be lost (source of truth)

### 3. Build System
- Webpack configuration for bundling
- React with Babel transpilation
- Output to `dist/` folder
- Bundle served by LocalHttpServer

## Files Created/Modified

**NEW** (entire module):
- Complete test-inventory-checker module structure
- All React components
- Build configuration
- Package.json with dependencies

**NO MODIFICATIONS** to existing code (this is standalone)

## Success Criteria

✅ Module builds successfully: `npm run build`
✅ Bundle created in `dist/` folder
✅ Module loads from `http://localhost:8080/test-inventory-checker/`
✅ Origin shows: `http://localhost:8080` (not `file://`)
✅ Feature 1 (Product Search) works - makes API call, displays results
✅ Feature 2 (Stock Count) works - saves to IndexedDB, retrieves data
✅ Feature 3 (Audit Trail) works - saves to Flutter SQLite via bridge
✅ IndexedDB data persists across app restart
✅ SQLite data persists across app restart
✅ No console errors

## Testing Approach

**Build Test**:
```bash
cd src/shell/assets/modules/test-inventory-checker
npm install
npm run build
# Check dist/ folder for bundle.js
```

**Manual Test**:
1. Build module
2. Load app
3. Navigate to test-inventory-checker
4. Test Feature 1: Search for "Widget"
5. Test Feature 2: Save 5 stock counts
6. Test Feature 3: Save 5 audit trails
7. Close app completely
8. Reopen app
9. Load module again
10. Verify Feature 2 data (IndexedDB) still there
11. Verify Feature 3 data (SQLite) still there

**WebView Console Tests**:
```javascript
// Check origin
console.log(window.location.origin);
// Expected: "http://localhost:8080"

// Test IndexedDB
// (Feature 2 should have data)

// Test SQLite bridge
await window.ActionQueue.getPending('test-inventory-checker');
// Should return saved audits
```

## Deliverables

- ✅ Working test module
- ✅ All 3 features functional
- ✅ Build output verified
- ✅ Persistence tested

---

# PHASE 5: TEST MODULE 2 - QUALITY INSPECTOR

**Duration**: 5-6 hours
**Type**: React Module Development

## Current State
- test-inventory-checker exists and works
- Need second module to validate isolation

## What Will Be Implemented

### 1. Module Structure
**Location**: `src/shell/assets/modules/test-quality-inspector/`

**Files to Create**: (Same structure as Phase 4)
```
test-quality-inspector/
├── package.json
├── webpack.config.js
├── public/
│   └── index.html
├── src/
│   ├── index.js
│   ├── App.jsx
│   ├── components/
│   │   ├── Feature1_DefectLookup.jsx       (online only)
│   │   ├── Feature2_InspectionLog.jsx      (IndexedDB)
│   │   └── Feature3_ReportQueue.jsx        (SQLite bridge)
│   └── utils/
│       ├── indexedDBHelper.js
│       └── actionQueueHelper.js
└── dist/
```

### 2. Three Features

**Feature 1: Defect Lookup (Online Only)**
- Input field for defect code
- Button to lookup
- API call to GET /api/defects/:code
- Display defect details
- No storage

**Feature 2: Inspection Log (IndexedDB - Expendable)**
- Form: Product, Result (pass/fail), Notes
- Save to IndexedDB (database: quality_inspector_db)
- List view showing logs
- Separate from Inventory Checker's IndexedDB

**Feature 3: Report Queue (SQLite Bridge - Critical)**
- Form: Report Type, Data, Timestamp
- Save to Flutter SQLite (module_id: test-quality-inspector)
- List view from SQLite
- Filtered by module_id (isolated from Inventory Checker)

### 3. Key Focus: Data Isolation
- Different IndexedDB database name
- Different module_id in SQLite actions
- Verify no cross-contamination with Inventory Checker

## Files Created/Modified

**NEW**:
- Complete test-quality-inspector module

**NO MODIFICATIONS** to existing code

## Success Criteria

✅ Module builds successfully
✅ Loads from `http://localhost:8080/test-quality-inspector/`
✅ Has separate IndexedDB database (not shared with Inventory Checker)
✅ SQLite actions filtered by module_id (no contamination)
✅ All 3 features work
✅ Data persists across restart
✅ Can switch between Module 1 and Module 2 without data loss
✅ Module isolation verified (no cross-contamination)

## Testing Approach

**Build Test**: (Same as Phase 4)

**Isolation Test**:
1. Load Inventory Checker
2. Save 5 actions in each feature
3. Switch to Quality Inspector
4. Save 3 actions in each feature
5. Switch back to Inventory Checker
6. Verify: Only 5 actions visible (not 8)
7. Switch to Quality Inspector
8. Verify: Only 3 actions visible (not 8)
9. Check IndexedDB databases in DevTools:
   - inventory_checker_db (separate)
   - quality_inspector_db (separate)
10. Check SQLite via bridge:
    ```javascript
    // In Inventory Checker
    await window.ActionQueue.getPending('test-inventory-checker');
    // Should return 5 actions

    // In Quality Inspector
    await window.ActionQueue.getPending('test-quality-inspector');
    // Should return 3 actions
    ```

## Deliverables

- ✅ Second test module working
- ✅ Data isolation confirmed
- ✅ No cross-contamination
- ✅ Test results documented

---

# PHASE 6: REFERENCE DATA MANAGER

**Duration**: 3-4 hours
**Type**: Reusable React Component

## Current State
- Modules directly call backend API
- No caching strategy
- No freshness checking
- No offline handling

## What Will Be Implemented

### Create Reusable Component
**File**: `src/shell/assets/modules/shared/ReferenceDataManager.js` (NEW)

**Responsibilities**:
- Fetch reference data from backend (products, customers, dropdowns)
- Store in IndexedDB with version and timestamps
- Check freshness on module load
- Auto-refresh when stale (expires_at < now)
- Handle offline (use cached data)
- Manual refresh trigger for users

**API**:
```javascript
class ReferenceDataManager {
  constructor(moduleId) { ... }

  async initialize()              // Setup on module load
  async fetch(dataType)           // Fetch from backend
  async refresh(dataType)         // Force refresh
  async get(dataType)             // Get from cache
  isStale(dataType)               // Check if expired
  async clear(dataType)           // Clear cache
}
```

**Storage** (IndexedDB):
```javascript
// Store: reference_data
{
  key: 'products',          // or 'customers', 'vendors'
  value: [...],             // Array of items
  version: '1.0',
  updated_at: 1678900000,
  expires_at: 1678986400    // 24h later
}
```

**Lifecycle**:
1. Module loads → Initialize manager
2. Check if reference data exists
3. If not found → fetch from API
4. If found → check if stale
5. If stale → refresh from API
6. Store in IndexedDB
7. Make available to UI components

### Integration Example
```javascript
// In module App.jsx
const refManager = new ReferenceDataManager('test-inventory-checker');
await refManager.initialize();

// Get products for dropdown
const products = await refManager.get('products');

// User pulls to refresh
async function handleRefresh() {
  await refManager.refresh('products');
}
```

## Files Created/Modified

**NEW**:
- `assets/modules/shared/ReferenceDataManager.js`

**MODIFIED** (in Phase 4 & 5 modules):
- Update both test modules to use ReferenceDataManager

## Success Criteria

✅ ReferenceDataManager class created
✅ Fetches reference data from backend on first load
✅ Stores in IndexedDB with version metadata
✅ Uses cached data when fresh
✅ Auto-refreshes when stale
✅ Works offline (uses cached data, doesn't crash)
✅ Manual refresh works
✅ Can be used by multiple modules independently
✅ No duplicate fetches (efficient)

## Testing Approach

**Unit Test**:
```javascript
describe('ReferenceDataManager', () => {
  test('fetches and caches data', async () => {
    const manager = new ReferenceDataManager('test');
    await manager.initialize();

    const products = await manager.fetch('products');
    expect(products.length).toBeGreaterThan(0);

    // Second call should use cache
    const cached = await manager.get('products');
    expect(cached).toEqual(products);
  });

  test('detects stale data', async () => {
    const manager = new ReferenceDataManager('test');
    // Mock stale data
    expect(manager.isStale('products')).toBe(true);
  });
});
```

**Integration Test**:
1. Load test module
2. Watch console - should fetch reference data
3. Check IndexedDB in DevTools - verify data stored
4. Reload module - should use cached data (no API call)
5. Manually update expires_at to past time
6. Reload module - should refresh from API
7. Go offline (airplane mode)
8. Reload module - should use cached data

## Deliverables

- ✅ ReferenceDataManager component
- ✅ Integrated into both test modules
- ✅ Cache strategy working
- ✅ Test results documented

---

# PHASE 7: SYNC MANAGER

**Duration**: 4-5 hours
**Type**: Reusable React Component

## Current State
- Actions saved to Flutter SQLite
- No sync to backend
- Actions remain "pending" forever

## What Will Be Implemented

### Create Sync Manager Component
**File**: `src/shell/assets/modules/shared/SyncManager.js` (NEW)

**Responsibilities**:
- Read pending actions from Flutter SQLite (via bridge)
- Process queue when online
- Send actions to backend API
- Handle 3 response types:
  - 200 OK → mark "synced"
  - 400 validation error → mark "error" (no retry)
  - 500/timeout → increment retry_count, keep "pending" (max 3 retries)
- Update action status in SQLite after each attempt
- Resume sync after module reload
- Provide status to UI

**API**:
```javascript
class SyncManager {
  constructor(moduleId) { ... }

  async initialize()          // Setup on module load
  async syncAll()             // Process all pending
  async syncOne(actionId)     // Process single action
  async retryFailed()         // Retry error actions
  getStatus()                 // { pending: 5, syncing: 1, errors: 2 }
}
```

**Sync Flow**:
```
1. Read pending actions from SQLite
   ↓
2. For each action:
   a. Mark as "syncing" in SQLite
   b. Determine API endpoint based on action_type
   c. Send HTTP request to backend
   d. Handle response:
      - 200 OK → mark "synced"
      - 400 validation → mark "error" (user must fix)
      - 500/timeout → retry_count++, keep "pending"
   e. If retry_count >= 3 → mark "error"
   ↓
3. Continue until queue empty or offline
```

**Triggers**:
- Module load
- App resume (listen to Flutter event)
- Network reconnect (listen to connectivity bridge)
- After new action added to queue
- Periodic timer (every 30 seconds while online)

**Error Handling**:
```javascript
// Validation error (400)
{
  status: 'error',
  error_message: 'Invalid PO number',
  retry_count: 0  // Don't retry
}

// Network error (500/timeout)
{
  status: 'pending',
  retry_count: 1  // Will retry
}

// Max retries reached
{
  status: 'error',
  error_message: 'Max retries reached',
  retry_count: 3
}
```

### UI Status Component
```jsx
<SyncStatus>
  {pending > 0 && <Badge color="yellow">🔄 {pending} pending</Badge>}
  {errors > 0 && <Badge color="red">⚠️ {errors} errors (tap to fix)</Badge>}
  {pending === 0 && errors === 0 && <Badge color="green">✅ All synced</Badge>}
</SyncStatus>
```

## Files Created/Modified

**NEW**:
- `assets/modules/shared/SyncManager.js`

**MODIFIED** (in test modules):
- Integrate SyncManager into both test modules
- Add sync status UI

## Success Criteria

✅ SyncManager reads pending actions from Flutter SQLite
✅ Syncs actions to correct backend endpoints
✅ Handles 200 OK (marks synced in SQLite)
✅ Handles 400 validation error (marks error, no retry)
✅ Handles 500/timeout (retries up to 3 times)
✅ Updates action status in SQLite correctly
✅ Triggers sync on module load
✅ Resumes sync after app restart
✅ Works across module switches
✅ Status UI updates in real-time
✅ User can see error details

## Testing Approach

**Unit Test**:
```javascript
describe('SyncManager', () => {
  test('syncs pending actions', async () => {
    // Create test actions in SQLite
    await createTestActions(5);

    const sync = new SyncManager('test-module');
    await sync.syncAll();

    // Verify all synced
    const pending = await window.ActionQueue.getPending('test-module');
    expect(pending.length).toBe(0);
  });

  test('handles validation errors', async () => {
    // Create invalid action
    await createInvalidAction();

    const sync = new SyncManager('test-module');
    await sync.syncAll();

    // Should be marked as error
    const errors = await getErrorActions();
    expect(errors.length).toBe(1);
    expect(errors[0].status).toBe('error');
  });
});
```

**Integration Test**:
1. Go offline (airplane mode)
2. Create 10 actions across both test modules
3. Verify actions in SQLite (all pending)
4. Go online
5. Wait for auto-sync (watch console)
6. Verify all actions synced
7. Check backend - verify data received
8. Create action with invalid data
9. Watch sync manager mark as error
10. Check UI - verify error badge shows

## Deliverables

- ✅ SyncManager component working
- ✅ Integrated into test modules
- ✅ Sync flow validated
- ✅ Error handling verified
- ✅ Test results documented

---

# PHASE 8: INTEGRATION TESTING

**Duration**: 3-4 hours
**Type**: End-to-End Validation

## Current State
- Both test modules working independently
- Reference Manager and Sync Manager integrated
- Need to validate complete flow

## What Will Be Tested

### Test Scenario 1: Offline Capture → Online Sync
**Steps**:
1. Enable airplane mode (offline)
2. Load Inventory Checker
3. Create 10 actions (Feature 3 - Audit Trail)
4. Load Quality Inspector
5. Create 5 actions (Feature 3 - Report Queue)
6. Verify all 15 actions in SQLite (pending status)
7. Disable airplane mode (online)
8. Wait for auto-sync
9. Verify all 15 actions synced
10. Check backend database

**Success**: All 15 actions in backend, marked "synced" in SQLite

### Test Scenario 2: Module Switching & Isolation
**Steps**:
1. Load Inventory Checker
2. Save data in all 3 features
3. Switch to Quality Inspector
4. Save data in all 3 features
5. Switch back to Inventory Checker
6. Verify: Only Inventory Checker data visible
7. Check IndexedDB databases (2 separate DBs)
8. Check SQLite actions (filtered by module_id)

**Success**: Complete data isolation, no contamination

### Test Scenario 3: Persistence Across Restarts
**Steps**:
1. Create 20 actions (10 per module)
2. Close app completely (kill process)
3. Wait 10 seconds
4. Reopen app
5. Load Inventory Checker → verify 10 actions
6. Load Quality Inspector → verify 10 actions
7. Verify IndexedDB data persists
8. Verify SQLite data persists

**Success**: 100% data persistence, zero loss

### Test Scenario 4: Error Handling Flow
**Steps**:
1. Create action with invalid data (e.g., invalid SKU)
2. Go online
3. Sync Manager processes action
4. Backend returns 400 validation error
5. Verify action marked "error" in SQLite
6. Verify error shown in UI
7. User edits action (fixes data)
8. User clicks retry
9. Verify action syncs successfully
10. Verify marked "synced"

**Success**: Error flow works, user can fix and retry

### Test Scenario 5: Reference Data Lifecycle
**Steps**:
1. Load module (first time)
2. Reference Manager fetches products
3. Verify stored in IndexedDB
4. Reload module (data fresh)
5. Verify uses cached data (no API call)
6. Simulate stale data (manually update expires_at)
7. Reload module
8. Verify auto-refresh triggered
9. Go offline
10. Reload module
11. Verify uses cached data (doesn't crash)

**Success**: Cache strategy works, offline graceful

## Files Created/Modified

**NEW**:
- `tests/integration/e2e_test_report.md` (test results)
- `tests/integration/test_scenarios.js` (automated tests)

**NO CODE CHANGES** (testing only)

## Success Criteria

✅ All 5 test scenarios pass
✅ Zero data loss in any scenario
✅ No cross-module contamination
✅ Sync reliability: 100%
✅ Error handling works correctly
✅ Reference data lifecycle correct
✅ Test report documented
✅ Screenshots/logs captured
✅ Performance acceptable:
  - Module load <3 seconds
  - Sync 50 actions <30 seconds
  - No memory leaks

## Testing Approach

**Automated Tests** (where possible):
```javascript
// tests/integration/e2e_test.js
describe('End-to-End Integration', () => {
  test('Scenario 1: Offline to Online', async () => {
    // Simulate offline
    // Create actions
    // Simulate online
    // Verify sync
  });

  // ... more scenarios
});
```

**Manual Testing**: All 5 scenarios with detailed logging

**Performance Testing**:
- Measure module load time
- Measure sync throughput
- Monitor memory usage

## Deliverables

- ✅ Test report: `e2e_test_report.md`
- ✅ All scenarios passed
- ✅ Performance metrics documented
- ✅ Screenshots of successful tests
- ✅ Any issues found and fixed

---

# PHASE 9: REBUILD SAMPLE-WAREHOUSE

**Duration**: 6-8 hours
**Type**: Production Module Migration

## Current State
- Old sample-warehouse using RxDB/Dexie
- Existing features: Receiving, Water Check, Complaint
- Existing bridges: scanner, photo, connectivity

## What Will Be Implemented

### 1. Archive Old Module
**Action**: Rename existing module
- FROM: `assets/modules/sample-warehouse/`
- TO: `assets/modules/sample-warehouse-old-backup/`

### 2. Create New Module Structure
**Location**: `src/shell/assets/modules/sample-warehouse/` (NEW)

**Files**:
```
sample-warehouse/
├── package.json
├── webpack.config.js
├── public/
│   └── index.html
├── src/
│   ├── index.js
│   ├── App.jsx
│   ├── components/
│   │   ├── ReceivingTransaction.jsx       (Feature 1)
│   │   ├── WaterTemperatureCheck.jsx      (Feature 2)
│   │   ├── ComplaintForm.jsx              (Feature 3)
│   │   └── SyncStatusBar.jsx
│   ├── managers/
│   │   ├── ReferenceDataManager.js   (from Phase 6)
│   │   └── SyncManager.js            (from Phase 7)
│   └── utils/
│       ├── indexedDBHelper.js
│       └── actionQueueHelper.js
└── dist/
```

### 3. Migrate Feature 1: Receiving Transaction

**Read Path** (Reference Data):
- Products, Vendors, Locations → ReferenceDataManager
- Stored in IndexedDB
- Dropdown menus populated from cache

**Write Path** (Transaction):
- User scans barcodes (existing scanner bridge)
- User fills form
- Create action with transaction data
- Save to Flutter SQLite via bridge
- Show "Saved offline" confirmation

**Data Flow**:
```
User scans item → Scanner Bridge → Barcode
User fills form → Validate
Create transaction payload
↓
window.ActionQueue.save(
  'sample-warehouse',
  'receiving_transaction',
  { po: '...', items: [...], ... }
)
↓
Flutter SQLite (source of truth)
↓
SyncManager reads and syncs to backend
```

### 4. Migrate Feature 2: Water Temperature Check

**Photo Capture**:
- User clicks "Take Photo"
- Call existing photo bridge: `window.shellBridge.call('capturePhoto')`
- Flutter saves photo to native storage
- Returns file path: `/storage/photos/photo_123.jpg`

**Data Capture**:
- User enters temperature
- Create action with photo_path
- Save to Flutter SQLite

**Sync**:
- SyncManager reads action
- Reads photo file from path
- Uploads to backend with data

**Data Flow**:
```
User takes photo → Photo Bridge → file_path
User enters temp → Create payload
↓
window.ActionQueue.save(
  'sample-warehouse',
  'water_check',
  {
    temp_f: 42,
    temp_c: 5.5,
    photo_path: '/storage/photos/photo_123.jpg',
    timestamp: ...
  }
)
↓
Flutter SQLite
↓
SyncManager → reads file → uploads to backend
```

### 5. Migrate Feature 3: Complaint Form

**Barcode Scan**:
- User clicks "Scan Barcode"
- Call scanner bridge
- Get barcode value

**Data Capture**:
- User fills complaint form
- Create action
- Save to SQLite

**Sync**:
- SyncManager syncs to backend

**Data Flow**:
```
User scans → Scanner Bridge → barcode
User fills form → Create payload
↓
window.ActionQueue.save(
  'sample-warehouse',
  'complaint',
  {
    barcode: '...',
    type: 'damage',
    description: '...',
    photo_path: '...'  (if photo taken)
  }
)
↓
Flutter SQLite → SyncManager → Backend
```

### 6. Integration with Existing Bridges
- Scanner bridge: KEEP AS-IS (already works)
- Photo bridge: KEEP AS-IS (already works)
- Connectivity bridge: USE for sync triggers
- No changes to Flutter bridge code

## Files Created/Modified

**DELETED** (archived):
- Old sample-warehouse moved to backup folder

**NEW**:
- Complete new sample-warehouse module

**MODIFIED**:
- `lib/modules/module_registry.dart` (update sample-warehouse path if needed)

## Success Criteria

✅ New sample-warehouse builds successfully
✅ All 3 features working:
  - Receiving Transaction (with scanner)
  - Water Temperature Check (with photo)
  - Complaint Form (with scanner & photo)
✅ Scanner bridge integrated correctly
✅ Photo bridge integrated correctly
✅ Reference data loads (products, vendors, locations)
✅ Offline capture works for all features
✅ Online sync works reliably
✅ Data persists across app restart
✅ Performance acceptable (<3s load, <20s sync for 50 actions)
✅ No errors in production use
✅ Code cleaner than old version

## Testing Approach

**Build Test**:
```bash
cd src/shell/assets/modules/sample-warehouse
npm install
npm run build
```

**Feature Tests**:

**Test 1: Receiving Transaction**
1. Load sample-warehouse
2. Scanner bridge → scan barcode
3. Fill transaction form
4. Submit
5. Verify saved to SQLite
6. Go online
7. Verify syncs to backend

**Test 2: Water Temperature Check**
1. Click "Take Photo"
2. Photo bridge captures
3. Enter temperature
4. Submit
5. Verify saved to SQLite with photo_path
6. Go online
7. Verify syncs with photo to backend

**Test 3: Complaint Form**
1. Scan barcode
2. Fill complaint form
3. Optionally take photo
4. Submit
5. Verify saved to SQLite
6. Go online
7. Verify syncs to backend

**Persistence Test**:
1. Create 20 transactions offline
2. Close app
3. Reopen
4. Verify all 20 still in SQLite
5. Sync to backend

**Performance Test**:
- Load time: <3 seconds
- Save action: <50ms
- Sync 50 actions: <30 seconds

## Deliverables

- ✅ New sample-warehouse module
- ✅ Old module archived
- ✅ All features working
- ✅ Test results documented
- ✅ Performance metrics captured

---

# PHASE 10: FINAL VALIDATION & DEPLOYMENT

**Duration**: 2-3 hours
**Type**: Production Readiness

## Current State
- sample-warehouse rebuilt and working
- Test modules validated
- Ready for final checks

## What Will Be Done

### 1. Performance Benchmarks
**Measure**:
- Module load time (target: <3s)
- Action save time (target: <50ms)
- IndexedDB read time (100 products: <100ms)
- SQLite save time (target: <30ms)
- Sync throughput (target: >4 actions/second)
- Photo upload time (2MB: <3s)

### 2. Stress Testing
**Test 1**: Create 100 actions offline
- Measure: Time to create
- Go online
- Measure: Time to sync all
- Expected: All sync successfully

**Test 2**: Rapid module switching
- Switch between modules 20 times
- Verify: No data loss, no crashes

**Test 3**: Network toggle stress
- Toggle online/offline 10 times during sync
- Verify: Graceful handling, no data loss

### 3. Edge Case Testing
**Test 1**: Kill app during sync
- Start sync
- Kill app mid-sync
- Reopen
- Verify: Resumes correctly

**Test 2**: Phone restart during offline capture
- Create actions offline
- Restart phone
- Open app
- Verify: All actions intact

**Test 3**: Low storage scenario
- Fill device storage
- Try to save actions
- Verify: Graceful error handling

### 4. Cross-Device Testing
**If possible**:
- Test on 2-3 different Android devices
- Test on different Android versions
- Document any device-specific issues

### 5. Documentation

**Create/Update**:
1. **Architecture Guide**: `docs/ARCHITECTURE_OVERVIEW.md`
   - Complete system design
   - Component diagrams
   - Data flow diagrams

2. **Developer Guide**: `docs/DEVELOPER_GUIDE.md`
   - How to create new modules
   - How to use ReferenceDataManager
   - How to use SyncManager
   - Bridge API reference

3. **Troubleshooting Guide**: `docs/TROUBLESHOOTING.md`
   - Common issues and solutions
   - Debug techniques
   - FAQ

4. **Deployment Checklist**: `docs/DEPLOYMENT_CHECKLIST.md`
   - Pre-deployment steps
   - Configuration verification
   - Post-deployment monitoring

### 6. Final Deployment Report

**Create**: `DEPLOYMENT_READY.md`

**Contents**:
- Architecture summary
- Modules ready for production
- Performance metrics
- Reliability test results
- Code quality metrics
- Known limitations
- Deployment readiness checklist
- Team sign-off

## Files Created/Modified

**NEW**:
- `docs/ARCHITECTURE_OVERVIEW.md`
- `docs/DEVELOPER_GUIDE.md`
- `docs/TROUBLESHOOTING.md`
- `docs/DEPLOYMENT_CHECKLIST.md`
- `DEPLOYMENT_READY.md`

**MODIFIED**:
- Update any outdated documentation

## Success Criteria

✅ Performance benchmarks met:
  - Load time: <3s ✅
  - Save time: <50ms ✅
  - Sync throughput: >4 actions/sec ✅
✅ Stress tests pass (100 actions, no failures)
✅ Edge cases handled gracefully
✅ No critical bugs found
✅ Documentation complete and reviewed
✅ Test coverage >80%
✅ Deployment checklist complete
✅ Team trained on new architecture
✅ Product owner approval
✅ Final report shows: READY FOR PRODUCTION ✅

## Testing Approach

**Performance Test Script**:
```javascript
// tests/performance/benchmark.js
async function runBenchmarks() {
  // Module load time
  const loadStart = Date.now();
  await loadModule('sample-warehouse');
  const loadTime = Date.now() - loadStart;
  console.log(`Load time: ${loadTime}ms`);

  // Action save time
  const saveStart = Date.now();
  await window.ActionQueue.save(...);
  const saveTime = Date.now() - saveStart;
  console.log(`Save time: ${saveTime}ms`);

  // Sync throughput
  await createActions(50);
  const syncStart = Date.now();
  await syncManager.syncAll();
  const syncTime = Date.now() - syncStart;
  console.log(`Sync time: ${syncTime}ms (${50000/syncTime} actions/sec)`);
}
```

**Stress Test Script**:
```javascript
// tests/stress/stress_test.js
async function stressTest() {
  // Create 100 actions
  for (let i = 0; i < 100; i++) {
    await createAction(i);
  }

  // Sync all
  const results = await syncAll();
  expect(results.success).toBe(100);
  expect(results.failed).toBe(0);
}
```

## Deliverables

- ✅ Performance benchmark report
- ✅ Stress test results
- ✅ Edge case test results
- ✅ Complete documentation set
- ✅ Deployment checklist
- ✅ Final readiness report
- ✅ Team sign-off
- ✅ Production deployment approved

---

# 📊 FINAL SUMMARY

## Implementation Complete When:

✅ **Phase 0**: Architecture documented
✅ **Phase 1**: Localhost HTTP server working
✅ **Phase 2**: SQLite action queue functional
✅ **Phase 3**: Backend APIs ready
✅ **Phase 4**: Test Module 1 working
✅ **Phase 5**: Test Module 2 working
✅ **Phase 6**: Reference Manager reusable
✅ **Phase 7**: Sync Manager functional
✅ **Phase 8**: Integration tests passing
✅ **Phase 9**: sample-warehouse rebuilt
✅ **Phase 10**: Production ready

## Key Deliverables

1. **Infrastructure**:
   - Local HTTP server (stable origin)
   - SQLite action queue (source of truth)
   - Backend API endpoints (6 new)

2. **Components**:
   - ReferenceDataManager (reusable)
   - SyncManager (reusable)
   - Bridge helper utilities

3. **Modules**:
   - test-inventory-checker (validation)
   - test-quality-inspector (validation)
   - sample-warehouse (production)

4. **Documentation**:
   - Architecture guide
   - Developer guide
   - Troubleshooting guide
   - Deployment checklist

5. **Testing**:
   - Integration test suite
   - Performance benchmarks
   - Stress test results
   - Production readiness report

## Success Metrics

- ✅ 100% data persistence (no loss)
- ✅ Stable origin (localhost, not file://)
- ✅ SQLite source of truth working
- ✅ Sync reliability: 100%
- ✅ Module isolation: Perfect
- ✅ Performance: Load <3s, Sync <30s for 50 actions
- ✅ Code quality: Clean, maintainable
- ✅ Team trained and ready

## Timeline

**Total**: 39-51 hours (5-7 working days)

**Week 1** (Days 1-3): Foundation
- Phases 0-3: Infrastructure

**Week 1** (Days 4-5): Test Modules
- Phases 4-5: Validation modules

**Week 2** (Days 1-2): Managers
- Phases 6-7: Reusable components

**Week 2** (Days 3-4): Production
- Phases 8-10: Integration, migration, validation

---

# 🎯 READY TO EXECUTE

This plan provides:
- ✅ Clear phase-by-phase roadmap
- ✅ Detailed implementation steps
- ✅ Success criteria for each phase
- ✅ Testing approach
- ✅ Clear deliverables

**Next Step**: Begin Phase 0 - Create architecture documentation

---

**Document Version**: 1.0
**Last Updated**: 2024-03-27
**Status**: Ready for Implementation
