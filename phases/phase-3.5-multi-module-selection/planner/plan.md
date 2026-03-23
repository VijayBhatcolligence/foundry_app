# Phase 3.5: Multiple Position Modules with Card Selection

**Status**: Planning
**Phase**: 3.5 - Multi-Module Selection UI
**Date**: 2026-03-16
**Planner**: Claude Sonnet 4.5

---

## Overview

Phase 3.5 adds the ability to support multiple React position modules with a card-based selection UI. Currently, the shell hardcodes the loading of a single module (`sample-warehouse`) after authentication. This phase introduces a module selection screen that allows users to choose from multiple available modules before loading the selected one in the WebView.

**What Changes**:
- After successful authentication, users see a card-based UI showing available position modules
- Each card displays module metadata (name, description, icon/visual)
- User taps a card to select which module to load
- WebView dynamically loads the selected module based on user choice
- Navigation flow: Login → Module Selection → WebView (Selected Module)

**What Stays The Same**:
- All Phase 1/2/3 infrastructure (auth, session, registry, cache, offline support)
- Module loading mechanism (cache-first, download, verify, fallback)
- Trust boundary and security model
- Bridge and runtime host architecture

---

## Scope

### In Scope

1. **Multi-Module Registry Support**
   - Extend ModuleRegistry to return a list of available modules for display
   - Add display metadata to ModuleMetadata (displayName, description, iconUrl)
   - Update mock registry to include 2+ example modules

2. **Card Selection UI (Flutter)**
   - New screen shown after login: ModuleSelectionScreen
   - Card-based grid/list layout
   - Display module metadata on each card
   - Tap to select functionality
   - Loading state while module loads

3. **Dynamic Module Loading**
   - Modify main.dart login flow to show selection screen instead of immediately loading WebView
   - Pass selected moduleId to WebView loading logic
   - Support loading different modules based on user selection

4. **Example React Modules**
   - Create 2 sample modules for demonstration:
     - `sample-warehouse` (already exists - reuse)
     - `sample-inventory` (new - minimal React app)
   - Each module has distinct UI to prove selection works

5. **Navigation State Management**
   - Track selected module in shell state
   - Support back navigation from WebView to card selection (optional but recommended)
   - Clear selection state on logout

### Out of Scope

- **User-specific module filtering**: All users see all modules (no role-based filtering yet)
- **Module categories or search**: Simple list/grid display only
- **Recently used / favorites**: No module history tracking
- **Module installation UI**: Download/install happens transparently on selection
- **Module updates notification**: Update checking remains background (Phase 3)
- **Multi-tenant module routing**: All users from same org see same modules
- **Offline-only modules list**: If offline, show cached modules only (no registry fetch)

---

## Technical Approach

### 1. Module Registry Enhancement

**Current State** (from `module_registry.dart`):
- `getLatestVersion(moduleId)` - returns single module by ID
- `getAvailableModules()` - returns all modules from registry (already supports multiple!)
- `ModuleMetadata` - has basic fields: moduleId, version, downloadUrl, etc.

**Changes Required**:

**1.1 Extend ModuleMetadata with Display Fields**

Add to `ModuleMetadata` class in `module_registry.dart`:
```dart
class ModuleMetadata {
  // Existing fields...
  final String moduleId;
  final String version;
  // ...existing fields...

  // NEW: Display metadata for selection UI
  final String displayName;       // Human-readable name: "Warehouse Clerk"
  final String description;        // Short description: "Receive goods and scan barcodes"
  final String? iconUrl;           // Optional icon URL (can be null for POC)
  final String? categoryId;        // Optional: "warehouse", "quality", etc. (future use)

  ModuleMetadata({
    required this.moduleId,
    required this.version,
    // ...existing params...
    required this.displayName,
    required this.description,
    this.iconUrl,
    this.categoryId,
    // ...existing params...
  });
}
```

**1.2 Update Mock Registry**

Update `_loadMockRegistry()` in `module_registry.dart` to include new modules:
```dart
final mockRegistryJson = {
  'modules': [
    {
      'moduleId': 'sample-warehouse',
      'version': '1.0.0',
      'displayName': 'Warehouse Clerk',
      'description': 'Receive goods against purchase orders and scan item barcodes',
      'iconUrl': null, // POC: no icon initially
      'categoryId': 'warehouse',
      // ...existing fields...
    },
    {
      'moduleId': 'sample-inventory',
      'version': '1.0.0',
      'displayName': 'Inventory Manager',
      'description': 'Count inventory and reconcile stock levels',
      'iconUrl': null,
      'categoryId': 'inventory',
      // ...existing fields...
    },
    {
      'moduleId': 'sample-quality',
      'version': '1.0.0',
      'displayName': 'Quality Inspector',
      'description': 'Perform inspections and capture defect photos',
      'iconUrl': null,
      'categoryId': 'quality',
      // ...existing fields...
    },
  ],
};
```

**1.3 Add Display-Focused Query Method**

Add to `ModuleRegistry` class:
```dart
// Returns list of unique modules (latest version only) for display
Future<List<ModuleMetadata>> getModulesForSelection() async {
  if (!_isLoaded) return [];

  final displayModules = <ModuleMetadata>[];
  for (final moduleId in _registry.keys) {
    final latestVersion = await getLatestVersion(moduleId);
    if (latestVersion != null) {
      displayModules.add(latestVersion);
    }
  }

  // Sort by displayName for consistent UI
  displayModules.sort((a, b) => a.displayName.compareTo(b.displayName));
  return displayModules;
}
```

---

### 2. Card Selection UI (Flutter)

**New File**: `src/shell/lib/screens/module_selection_screen.dart`

**Widget Structure**:
```
ModuleSelectionScreen (StatefulWidget)
├─ AppBar (title: "Select Position Module")
├─ ModuleGridView or ModuleListView
│  └─ List of ModuleCard widgets
└─ Loading/Error states
```

**Component Design**:

**2.1 ModuleSelectionScreen**
```dart
class ModuleSelectionScreen extends StatefulWidget {
  final Position currentPosition;
  final Function(String moduleId) onModuleSelected;

  const ModuleSelectionScreen({
    required this.currentPosition,
    required this.onModuleSelected,
  });

  @override
  State<ModuleSelectionScreen> createState() => _ModuleSelectionScreenState();
}

class _ModuleSelectionScreenState extends State<ModuleSelectionScreen> {
  late final ModuleRegistry _registry;
  List<ModuleMetadata>? _modules;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _registry = ModuleRegistry.instance;
    _loadModules();
  }

  Future<void> _loadModules() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final modules = await _registry.getModulesForSelection();
      setState(() {
        _modules = modules;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load modules: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Position Module'),
        automaticallyImplyLeading: false, // No back button
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: TextStyle(color: Colors.red)),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadModules,
              child: Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_modules == null || _modules!.isEmpty) {
      return const Center(child: Text('No modules available'));
    }

    // Grid layout for cards (2 columns on tablet, 1 on phone)
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 400,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 1.5,
      ),
      itemCount: _modules!.length,
      itemBuilder: (context, index) {
        return ModuleCard(
          module: _modules![index],
          onTap: () => widget.onModuleSelected(_modules![index].moduleId),
        );
      },
    );
  }
}
```

**2.2 ModuleCard Widget**
```dart
class ModuleCard extends StatelessWidget {
  final ModuleMetadata module;
  final VoidCallback onTap;

  const ModuleCard({
    required this.module,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon placeholder (future: load from iconUrl)
              Icon(
                Icons.apps,
                size: 48,
                color: Theme.of(context).primaryColor,
              ),
              SizedBox(height: 12),
              // Display name
              Text(
                module.displayName,
                style: Theme.of(context).textTheme.titleLarge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 8),
              // Description
              Expanded(
                child: Text(
                  module.description,
                  style: Theme.of(context).textTheme.bodyMedium,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Version badge
              SizedBox(height: 8),
              Text(
                'v${module.version}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

---

### 3. Dynamic Module Loading

**File to Modify**: `src/shell/lib/main.dart`

**Current Flow**:
```
Login → _handleLogin() → _loadRuntimeHost() → WebView loads hardcoded 'sample-warehouse'
```

**New Flow**:
```
Login → _handleLogin() → Navigate to ModuleSelectionScreen
User selects module → onModuleSelected(moduleId) callback
Callback triggers → _loadSelectedModule(moduleId) → WebView loads selected module
```

**3.1 Update State in _ShellHomePageState**

Add to state class:
```dart
class _ShellHomePageState extends State<ShellHomePage> {
  // Existing state...
  bool _isAuthenticated = false;
  Position? _currentPosition;

  // NEW: Module selection state
  bool _showModuleSelection = false;
  String? _selectedModuleId;

  // ...rest of existing state...
}
```

**3.2 Modify _handleLogin()**

Change end of `_handleLogin()` method:
```dart
Future<void> _handleLogin() async {
  // ...existing authentication code...

  _currentPosition = await _positionResolver.resolvePosition(username);
  _shellBridge.setCurrentPosition(_currentPosition!);

  setState(() {
    _isAuthenticated = true;
    _showModuleSelection = true;  // NEW: Show selection screen
    _statusMessage = 'Select a position module';
  });

  // REMOVE: Direct call to _loadRuntimeHost()
  // OLD: await _loadRuntimeHost();
}
```

**3.3 Add Module Selection Callback**

New method in `_ShellHomePageState`:
```dart
Future<void> _handleModuleSelected(String moduleId) async {
  setState(() {
    _isLoading = true;
    _statusMessage = 'Loading module: $moduleId';
    _selectedModuleId = moduleId;
  });

  try {
    await _loadRuntimeHost(moduleId);

    setState(() {
      _showModuleSelection = false;
      _isLoading = false;
      _statusMessage = 'Module loaded: $moduleId';
    });
  } catch (e) {
    setState(() {
      _isLoading = false;
      _statusMessage = 'Error loading module: $e';
    });
  }
}
```

**3.4 Update _loadRuntimeHost() Signature**

Change:
```dart
// OLD
Future<void> _loadRuntimeHost() async {
  final positionName = _currentPosition?.positionName ?? 'Unknown';

  // Hardcoded module
  print('[ModuleCache] Checking cache for module: sample-warehouse');
  final cachedModulePath = await _moduleCache.getCachedModulePath('sample-warehouse', '1.0.0');
  // ...
}

// NEW
Future<void> _loadRuntimeHost(String moduleId) async {
  final positionName = _currentPosition?.positionName ?? 'Unknown';

  // Use provided moduleId instead of hardcoded value
  print('[ModuleCache] Checking cache for module: $moduleId');

  // Get module metadata from registry
  final moduleMetadata = await _moduleRegistry.getLatestVersion(moduleId);
  if (moduleMetadata == null) {
    throw Exception('Module not found: $moduleId');
  }

  final cachedModulePath = await _moduleCache.getCachedModulePath(
    moduleId,
    moduleMetadata.version,
  );
  // ...rest of loading logic...
}
```

**3.5 Update build() Method**

Modify widget tree to show selection screen:
```dart
@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: const Text('Foundry Shell'),
      actions: [
        if (_isAuthenticated)
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout,
            tooltip: 'Logout',
          ),
      ],
    ),
    body: Column(
      children: [
        // Status bar
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          color: _isAuthenticated ? Colors.green.shade700 : Colors.blue.shade700,
          child: Text(
            _statusMessage,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ),

        // Main content area
        Expanded(
          child: _buildMainContent(),
        ),
      ],
    ),
  );
}

Widget _buildMainContent() {
  if (!_isAuthenticated) {
    return _buildLoginForm();
  }

  if (_showModuleSelection) {
    return ModuleSelectionScreen(
      currentPosition: _currentPosition!,
      onModuleSelected: _handleModuleSelected,
    );
  }

  return _buildWebViewContainer();
}
```

**3.6 Update _handleLogout()**

Clear selection state:
```dart
Future<void> _handleLogout() async {
  await _authService.logout();
  _shellBridge.clearPosition();

  setState(() {
    _isAuthenticated = false;
    _currentPosition = null;
    _showModuleSelection = false;  // NEW
    _selectedModuleId = null;      // NEW
    _statusMessage = 'Logged out';
  });

  await _webViewController.loadHtmlString('<html><body></body></html>');
}
```

---

### 4. Example React Modules

**4.1 Reuse Existing: sample-warehouse**

Already exists in Phase 1/2/3. No changes needed to the module itself, just ensure registry metadata is updated.

**4.2 Create New: sample-inventory**

**New File**: `src/modules/sample-inventory/index.html`

Minimal React module to demonstrate selection works:
```html
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Sample Inventory Module</title>
  <script crossorigin src="https://unpkg.com/react@18/umd/react.production.min.js"></script>
  <script crossorigin src="https://unpkg.com/react-dom@18/umd/react-dom.production.min.js"></script>
  <script src="https://unpkg.com/@babel/standalone/babel.min.js"></script>
  <style>
    body {
      margin: 0;
      padding: 20px;
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      min-height: 100vh;
    }
    .container {
      max-width: 600px;
      margin: 0 auto;
      background: white;
      padding: 24px;
      border-radius: 12px;
      box-shadow: 0 4px 6px rgba(0,0,0,0.1);
    }
    h1 {
      color: #667eea;
      margin-top: 0;
    }
    .count-display {
      font-size: 48px;
      font-weight: bold;
      color: #764ba2;
      text-align: center;
      margin: 32px 0;
    }
    button {
      width: 100%;
      padding: 16px;
      margin: 8px 0;
      font-size: 18px;
      border: none;
      border-radius: 8px;
      background: #667eea;
      color: white;
      cursor: pointer;
    }
    button:hover {
      background: #5568d3;
    }
  </style>
</head>
<body>
  <div id="root"></div>

  <script type="text/babel">
    const { useState } = React;

    function InventoryModule() {
      const [count, setCount] = useState(0);
      const [items, setItems] = useState([]);

      const incrementCount = () => {
        setCount(count + 1);
        setItems([...items, { id: Date.now(), count: count + 1 }]);
      };

      const resetCount = () => {
        setCount(0);
        setItems([]);
      };

      return (
        <div className="container">
          <h1>📦 Inventory Module</h1>
          <p>Sample inventory counting module - demonstrates module selection</p>

          <div className="count-display">
            {count}
          </div>

          <button onClick={incrementCount}>
            Count Item
          </button>

          <button onClick={resetCount} style={{background: '#764ba2'}}>
            Reset Count
          </button>

          <div style={{marginTop: '24px'}}>
            <h3>Recent Counts:</h3>
            {items.slice(-5).reverse().map(item => (
              <div key={item.id} style={{padding: '8px', borderBottom: '1px solid #eee'}}>
                Count: {item.count}
              </div>
            ))}
          </div>
        </div>
      );
    }

    ReactDOM.render(<InventoryModule />, document.getElementById('root'));

    console.log('[SampleInventory] Module mounted');
  </script>
</body>
</html>
```

**4.3 Optional: Create sample-quality**

Similar structure to sample-inventory, but with quality inspection theme (purple/green color scheme, different icons).

**Note**: For POC, 2 modules (warehouse + inventory) are sufficient. Third module can be added if needed.

---

### 5. State Management

**5.1 Shell State Tracking**

State variables in `_ShellHomePageState`:
- `_isAuthenticated: bool` - User has logged in
- `_showModuleSelection: bool` - Show selection screen vs WebView
- `_selectedModuleId: String?` - Currently selected module ID
- `_currentPosition: Position?` - User's position context

**State Transitions**:
```
Initial: _isAuthenticated=false, _showModuleSelection=false, _selectedModuleId=null
  ↓ [User logs in]
Authenticated: _isAuthenticated=true, _showModuleSelection=true, _selectedModuleId=null
  ↓ [User selects module]
Loading: _isAuthenticated=true, _showModuleSelection=true, _selectedModuleId='sample-warehouse', _isLoading=true
  ↓ [Module loads successfully]
Module Active: _isAuthenticated=true, _showModuleSelection=false, _selectedModuleId='sample-warehouse'
  ↓ [User logs out]
Back to Initial
```

**5.2 Back Navigation (Optional)**

Add back button in WebView container to return to module selection:

```dart
Widget _buildWebViewContainer() {
  return Column(
    children: [
      // Position info bar
      if (_currentPosition != null)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          color: Colors.grey.shade200,
          child: Row(
            children: [
              // NEW: Back button
              IconButton(
                icon: Icon(Icons.arrow_back),
                onPressed: _handleBackToModuleSelection,
                tooltip: 'Back to module selection',
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Position: ${_currentPosition!.positionName}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Module: $_selectedModuleId',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

      // WebView
      Expanded(
        child: WebViewWidget(controller: _webViewController),
      ),
    ],
  );
}

void _handleBackToModuleSelection() {
  setState(() {
    _showModuleSelection = true;
    _selectedModuleId = null;
    _statusMessage = 'Select a position module';
  });

  // Clear WebView
  _webViewController.loadHtmlString('<html><body></body></html>');
}
```

**5.3 Logout Cleanup**

Ensure all module-related state is cleared:
```dart
Future<void> _handleLogout() async {
  await _authService.logout();
  _shellBridge.clearPosition();

  setState(() {
    _isAuthenticated = false;
    _currentPosition = null;
    _showModuleSelection = false;
    _selectedModuleId = null;
    _statusMessage = 'Logged out';
  });

  await _webViewController.loadHtmlString('<html><body></body></html>');
}
```

---

## File Manifest

### Files to Modify

| File Path | Changes | Complexity |
|-----------|---------|------------|
| `src/shell/lib/modules/module_registry.dart` | Add display metadata fields to ModuleMetadata; update mock registry with 2+ modules; add `getModulesForSelection()` method | Medium |
| `src/shell/lib/main.dart` | Add module selection state; modify login flow to show selection screen; update `_loadRuntimeHost()` to accept moduleId; add back navigation; update build() logic | High |

### Files to Create

| File Path | Purpose | Complexity |
|-----------|---------|------------|
| `src/shell/lib/screens/module_selection_screen.dart` | Card-based module selection UI with grid layout | Medium |
| `src/modules/sample-inventory/index.html` | Second example React module for demonstration | Low |
| `src/modules/sample-quality/index.html` | (Optional) Third example React module | Low |

### Supporting Files

| File Path | Purpose | Complexity |
|-----------|---------|------------|
| `phases/phase-3.5-multi-module-selection/planner/plan.md` | This planning document | - |
| `phases/phase-3.5-multi-module-selection/ACCEPTANCE_CRITERIA.md` | Detailed AC definitions (to be created by validator) | - |

---

## Acceptance Criteria

### AC-3.5.1: Module Selection Screen Display
**Given** user has successfully authenticated
**When** authentication completes
**Then** user sees a card-based module selection screen with at least 2 module cards

**Verification**:
- Login with demo credentials
- Observe screen shows "Select Position Module" title
- Observe at least 2 cards are visible
- Each card shows displayName, description, and version

---

### AC-3.5.2: Registry Contains Multiple Modules
**Given** the mock registry is loaded
**When** `getModulesForSelection()` is called
**Then** registry returns at least 2 distinct modules with display metadata

**Verification**:
- Unit test: Load mock registry and verify count
- Verify each module has non-empty displayName and description
- Verify modules are sorted by displayName

---

### AC-3.5.3: Module Card Selection
**Given** module selection screen is displayed
**When** user taps a module card
**Then** the selected module begins loading

**Verification**:
- Tap on "Warehouse Clerk" card
- Observe status message changes to "Loading module: sample-warehouse"
- Observe loading indicator appears

---

### AC-3.5.4: WebView Loads Selected Module
**Given** user has selected a module
**When** module loading completes
**Then** WebView displays the correct React module for the selected moduleId

**Verification**:
- Select "Warehouse Clerk" → verify WebView shows warehouse UI
- Logout, login again
- Select "Inventory Manager" → verify WebView shows inventory UI
- Confirm different modules render different UIs

---

### AC-3.5.5: Back Navigation to Selection
**Given** a module is loaded in WebView
**When** user taps the back button
**Then** module selection screen reappears

**Verification**:
- Load any module
- Observe back button in position info bar
- Tap back button
- Verify module selection screen is shown again
- Verify WebView is cleared

---

### AC-3.5.6: Selection State Clears on Logout
**Given** a module is selected and loaded
**When** user logs out
**Then** all module selection state is cleared

**Verification**:
- Select and load a module
- Tap logout
- Log in again
- Verify module selection screen appears (not auto-loaded module)
- Verify no previous selection is remembered

---

### AC-3.5.7: Module Metadata Display
**Given** module cards are rendered
**When** user views the selection screen
**Then** each card displays: displayName, description, version, and placeholder icon

**Verification**:
- Visually inspect each card
- Verify displayName is prominent (large text)
- Verify description is readable (smaller text, 2-3 lines)
- Verify version badge shows "v1.0.0"
- Verify icon placeholder is visible

---

### AC-3.5.8: Error Handling for Missing Module
**Given** user selects a module
**When** the module cannot be loaded (not in registry or download fails)
**Then** error message is displayed and user can retry or go back

**Verification**:
- Unit test: Mock registry to return empty list
- Verify "No modules available" message shows
- Simulate network error during module load
- Verify error message displays
- Verify user can tap retry or go back to selection

---

## Integration Points

### Builds on Phase 1 (Foundation)
- Uses existing auth flow (`MockAuthService`, `PositionResolver`, `SessionBroker`)
- Uses existing WebView setup and bridge injection
- Maintains shell/runtime-host/module boundary

### Builds on Phase 2 (Trust & Delivery)
- Uses `ModuleRegistry` for module discovery (extends with display metadata)
- Uses `ModuleCache` and `ModuleLoader` for loading selected module
- Uses `ModuleVerifier` for signature verification (no changes needed)
- Uses `FallbackManager` for last-known-good fallback (no changes needed)

### Builds on Phase 3 (Offline Support)
- Leverages cache-first loading for offline module availability
- Uses `NetworkMonitor` to detect if module download is possible
- Compatible with offline transaction queue (no interaction needed)
- Compatible with update scheduler (no interaction needed)

### No Breaking Changes
- All existing Phase 1/2/3 functionality remains intact
- Only change is login flow now shows selection screen instead of auto-loading module
- Existing tests for Phase 1/2/3 should continue to pass

---

## Risk Assessment

### Technical Risks

**Risk 1: Module Registry Metadata Schema Change**
- **Impact**: Medium
- **Probability**: Low
- **Mitigation**:
  - Add display fields as optional with defaults
  - Ensure backward compatibility with existing registry format
  - Use safe fallbacks (e.g., moduleId as displayName if missing)

**Risk 2: State Management Complexity**
- **Impact**: Medium
- **Probability**: Medium
- **Mitigation**:
  - Keep state transitions simple and documented
  - Use explicit boolean flags instead of complex enums
  - Add state validation asserts in debug mode

**Risk 3: WebView Clear/Reload Between Modules**
- **Impact**: Medium
- **Probability**: Low
- **Description**: Switching modules might leave WebView in dirty state
- **Mitigation**:
  - Always call `loadHtmlString('<html><body></body></html>')` before loading new module
  - Clear JavaScript context between loads
  - Test rapid module switching in testing phase

**Risk 4: Module Selection Screen Performance**
- **Impact**: Low
- **Probability**: Low
- **Description**: Large number of modules might slow down grid rendering
- **Mitigation**:
  - Use `ListView.builder` or `GridView.builder` for lazy loading
  - Limit initial mock registry to 3-5 modules
  - Document scaling considerations for production

---

### Implementation Risks

**Risk 5: Scope Creep into Role-Based Filtering**
- **Impact**: High (delays phase)
- **Probability**: Medium
- **Mitigation**: Explicitly mark as out-of-scope in plan
- **Decision Rule**: If user asks for filtering, defer to Phase 4 or later

**Risk 6: Over-Engineering Module Card UI**
- **Impact**: Medium (time waste)
- **Probability**: Medium
- **Mitigation**:
  - Use simple Material Design cards
  - Skip custom animations initially
  - Placeholder icon (Flutter Icons.apps) instead of loading remote images

---

## Testing Strategy

### Unit Tests

**File**: `test/modules/module_registry_test.dart`

New tests to add:
- `test('getModulesForSelection returns unique modules')`
- `test('getModulesForSelection returns latest version only')`
- `test('getModulesForSelection sorts by displayName')`
- `test('ModuleMetadata includes display fields')`
- `test('Mock registry contains multiple modules')`

**File**: `test/screens/module_selection_screen_test.dart` (new)

Tests to create:
- `test('Renders grid of module cards')`
- `test('Shows loading state initially')`
- `test('Shows error state on registry load failure')`
- `test('Shows retry button on error')`
- `test('Calls onModuleSelected when card tapped')`
- `test('Shows empty state when no modules available')`

---

### Widget Tests

**File**: `test/widgets/module_card_test.dart` (new)

Tests to create:
- `test('ModuleCard displays displayName')`
- `test('ModuleCard displays description')`
- `test('ModuleCard displays version')`
- `test('ModuleCard displays icon placeholder')`
- `test('ModuleCard responds to tap')`
- `test('ModuleCard truncates long text with ellipsis')`

---

### Integration Tests

**File**: `integration_test/module_selection_flow_test.dart` (new)

End-to-end flow tests:
- `test('Login → See module selection → Tap card → Module loads')`
- `test('Load module → Back button → See selection again')`
- `test('Load module → Logout → Login → See selection')`
- `test('Select warehouse → See warehouse UI')`
- `test('Select inventory → See inventory UI')`
- `test('Switch modules without logout')`

---

### Manual Testing Checklist

- [ ] Login shows module selection screen (not WebView)
- [ ] At least 2 module cards visible
- [ ] Card displays: displayName, description, version, icon
- [ ] Tap warehouse card → Warehouse module loads
- [ ] Tap inventory card → Inventory module loads
- [ ] Back button returns to selection screen
- [ ] WebView clears when going back
- [ ] Logout clears selection state
- [ ] Re-login shows selection screen again
- [ ] Rapid module switching works without crashes
- [ ] Module selection works offline (if modules cached)
- [ ] Network error during load shows error message

---

## UNCLEAR Items

### For VALIDATOR Review

**UNCLEAR-1: Icon Loading Strategy**
- **Question**: Should icons be loaded from remote URLs or bundled with shell?
- **Options**:
  - A) Load from `iconUrl` field (requires image caching)
  - B) Use bundled Flutter assets (requires asset management)
  - C) Use Material icons only (simplest for POC)
- **Recommendation**: Start with C (Material icons), document URL loading as Phase 3.6 enhancement
- **Validator Decision**: _______________

**UNCLEAR-2: Module Filtering by Position**
- **Question**: Should module list be filtered based on user's position?
- **Example**: Warehouse clerk sees only warehouse modules, not quality modules
- **Recommendation**: Out of scope for 3.5 - show all modules to all users
- **Validator Decision**: _______________

**UNCLEAR-3: Cached-Only Mode When Offline**
- **Question**: When offline, should selection screen show only cached modules or all registry modules?
- **Options**:
  - A) Show all modules, but gray out uncached ones
  - B) Show only cached modules
  - C) Show all, let user tap, then show "offline" error
- **Recommendation**: Option C for simplicity, document offline UX as Phase 3.6 enhancement
- **Validator Decision**: _______________

**UNCLEAR-4: Module Switching vs Session Invalidation**
- **Question**: When user switches modules, should we invalidate session or keep same session?
- **Context**: Phase 1 established position-scoped sessions. Switching modules might require fresh session.
- **Recommendation**: For Phase 3.5, keep same session (no fresh bootstrap). Document as Phase 4 concern.
- **Validator Decision**: _______________

**UNCLEAR-5: Number of Example Modules**
- **Question**: How many example modules should we create?
- **Options**: 2 (warehouse + inventory) or 3 (+ quality)
- **Recommendation**: Start with 2, add third only if needed for testing
- **Validator Decision**: _______________

---

## Implementation Sequence

### Step 1: Extend Module Registry (1-2 hours)
1. Add display fields to `ModuleMetadata`
2. Update `_loadMockRegistry()` with 2 modules
3. Add `getModulesForSelection()` method
4. Write unit tests

### Step 2: Create Module Selection UI (2-3 hours)
1. Create `module_selection_screen.dart`
2. Implement `ModuleCard` widget
3. Write widget tests
4. Test grid layout and tap handling

### Step 3: Update Main.dart Navigation (2-3 hours)
1. Add module selection state variables
2. Modify `_handleLogin()` to show selection
3. Add `_handleModuleSelected()` callback
4. Update `_loadRuntimeHost()` signature
5. Update `build()` logic
6. Add back navigation

### Step 4: Create Second Example Module (1 hour)
1. Create `sample-inventory/index.html`
2. Implement simple React counter UI
3. Test loading in WebView

### Step 5: Integration Testing (2-3 hours)
1. Write integration tests
2. Manual end-to-end testing
3. Test module switching
4. Test offline scenarios

### Step 6: Documentation (1 hour)
1. Update README with new flow
2. Document module registry schema
3. Add screenshots to docs

**Total Estimated Effort**: 9-13 hours

---

## Success Metrics

- [ ] At least 2 example modules in registry
- [ ] Module selection screen renders without errors
- [ ] User can select and load different modules
- [ ] Back navigation works correctly
- [ ] All Phase 1/2/3 tests still pass (no regression)
- [ ] New unit tests pass (>90% coverage for new code)
- [ ] Integration tests pass
- [ ] Manual testing checklist complete

---

## Dependencies

### Phase Dependencies
- **Requires**: Phase 1 (Foundation) - COMPLETE
- **Requires**: Phase 2 (Trust & Delivery) - COMPLETE
- **Requires**: Phase 3 (Offline Support) - COMPLETE
- **Enables**: Phase 4 (Role switching, multi-position)

### External Dependencies
- None (all Flutter/Dart standard libraries)
- React modules use CDN (no build step required for POC)

---

## Notes for BUILDER

1. **Start Simple**: Begin with basic card layout, enhance UI later if needed
2. **Reuse Existing Code**: Leverage `ModuleRegistry.getAvailableModules()` - it already supports multiple modules!
3. **Keep State Flat**: Use simple boolean flags instead of complex state machines
4. **Test Incrementally**: Test each step before moving to next
5. **Don't Over-Engineer**: This is POC - simple Material cards are fine, no custom animations
6. **Verify Regression**: Run Phase 1/2/3 tests after changes to ensure no breakage

---

## Notes for VALIDATOR

1. **Review UNCLEAR items** and provide decisions
2. **Verify AC definitions** are testable and complete
3. **Check scope boundaries** - flag if implementation starts adding features marked as out-of-scope
4. **Review mock registry design** - should we add more modules or keep it minimal?
5. **Clarify offline behavior** - how should selection screen behave when network is unavailable?

---

**END OF PLAN**
