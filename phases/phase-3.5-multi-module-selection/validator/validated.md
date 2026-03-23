# Phase 3.5 Validation Report

**Status**: APPROVED
**Validator**: Claude Sonnet 4.5
**Date**: 2026-03-16
**Plan Version**: phase-3.5-multi-module-selection/planner/plan.md

---

## Overview

The PLANNER's plan for Phase 3.5 is **well-structured and implementation-ready** with appropriate scope boundaries. The plan correctly identifies this as an extension phase that builds on the existing Phase 1/2/3 foundation without breaking existing functionality.

**Key Strengths**:
- Clear separation of concerns (registry enhancement, UI layer, navigation flow)
- Maintains all Phase 1/2/3 trust boundaries and security model
- Appropriate POC scope (simple card selection, no over-engineering)
- Comprehensive acceptance criteria with testable verification steps
- Realistic effort estimation (9-13 hours)

**Readiness Assessment**: The plan is ready for BUILDER execution once the 5 UNCLEAR items are resolved with specific decisions below.

---

## UNCLEAR Item Resolutions

### UNCLEAR-1: Icon Loading Strategy

**Decision**: Use Material icons only (Option C)

**Rationale**:
- POC context prioritizes speed and simplicity over production polish
- Material icons are zero-cost (bundled with Flutter framework)
- No external dependencies or asset management complexity
- No network requests or caching infrastructure needed
- Sufficient for demonstrating module selection functionality
- Each module card can use a distinct Material icon to visually differentiate modules

**Implementation Details for BUILDER**:
```dart
// In ModuleCard widget:
Icon _getModuleIcon(String moduleId) {
  switch (moduleId) {
    case 'sample-warehouse':
      return Icon(Icons.warehouse, size: 48, color: Theme.of(context).primaryColor);
    case 'sample-inventory':
      return Icon(Icons.inventory_2, size: 48, color: Theme.of(context).primaryColor);
    case 'sample-quality':
      return Icon(Icons.verified, size: 48, color: Theme.of(context).primaryColor);
    default:
      return Icon(Icons.apps, size: 48, color: Theme.of(context).primaryColor);
  }
}
```

**DO NOT**:
- Add `iconUrl` field to ModuleMetadata (not needed for POC)
- Implement remote image loading or caching
- Add asset bundles for custom icons

**Document for Future**:
- Note in plan that icon URL loading is a Phase 3.6+ enhancement
- Production implementation can load from `iconUrl` field when needed

---

### UNCLEAR-2: Module Filtering by Position

**Decision**: Show all modules to all users (no position-based filtering)

**Rationale**:
- POC scenarios (foundry-position-shell-poc-scenarios.md) do not specify position-based access control requirements
- Parity evaluation focuses on technical capability (offline, scanning, biometrics) not role-based access
- Filtering logic adds complexity that is not core to proving the multi-module selection architecture
- User can self-select appropriate module for their workflow
- Position-scoped sessions (Phase 1) already provide security boundary AFTER module is loaded
- This is explicitly marked as "Out of Scope" in the plan under "User-specific module filtering"

**Implementation Details for BUILDER**:
- `getModulesForSelection()` returns ALL modules in registry
- No filtering logic based on `currentPosition.positionName`
- Module selection screen displays all available modules
- User taps any module to load it

**Example**:
```dart
// In ModuleSelectionScreen - NO filtering needed
Future<void> _loadModules() async {
  // Returns all modules, no position filter
  final modules = await _registry.getModulesForSelection();
  setState(() {
    _modules = modules;
  });
}
```

**Document for Future**:
- Phase 4+ can add position-to-module mapping in registry
- Can filter modules by `categoryId` matching position type
- Example: warehouse position sees only `categoryId: 'warehouse'` modules

---

### UNCLEAR-3: Offline Display

**Decision**: Show all registry modules when offline, allow user to tap, display error if module not cached (Option C)

**Rationale**:
- Simplest implementation for POC (no additional offline detection logic in UI layer)
- Follows existing Phase 3 offline handling pattern: attempt operation, fail gracefully
- User gets immediate feedback on tap if module is not available offline
- Avoids premature optimization of offline UX before understanding real usage patterns
- NetworkMonitor and ModuleCache already handle offline detection during module load
- Consistent with POC principle: simple path first, enhance based on evidence

**Implementation Details for BUILDER**:

1. **Module Selection Screen**: Always show all modules from registry (no graying out, no filtering)
   ```dart
   // ModuleSelectionScreen loads registry normally
   final modules = await _registry.getModulesForSelection();
   // Display all modules regardless of cache state
   ```

2. **Error Handling on Selection**: Let existing module loading logic detect offline/uncached state
   ```dart
   // In _handleModuleSelected callback in main.dart
   try {
     await _loadRuntimeHost(moduleId);
   } catch (e) {
     // This will catch "Module not cached" errors from ModuleCache
     setState(() {
       _statusMessage = 'Error: Module not available offline';
       _showModuleSelection = true; // Stay on selection screen
     });
   }
   ```

3. **User Flow**:
   - Offline with cached warehouse module: Tap warehouse → loads successfully
   - Offline without cached inventory module: Tap inventory → Error message displays → User stays on selection screen

**DO NOT**:
- Add offline detection in ModuleSelectionScreen
- Gray out uncached modules
- Filter modules list based on cache state
- Pre-check cache status for each module before display

**Document for Future**:
- Phase 3.6+ can add cache status indicators (badge showing "Available offline")
- Can disable/gray uncached modules when NetworkMonitor.isOffline == true
- Can add retry with "Download module" prompt when online

---

### UNCLEAR-4: Module Switching Session Handling

**Decision**: Keep same session when switching modules (no fresh session on module switch)

**Rationale**:
- Phase 3.5 is focused on **selection UI**, not session security model changes
- Phase 1 established position-scoped sessions tied to login/position resolution
- Switching modules within same login session does not change user's position
- Adding session invalidation on module switch would require:
  - Session broker changes (out of Phase 3.5 scope)
  - New bootstrap flow on every module load (performance impact)
  - Complexity not needed to prove multi-module selection works
- POC scenarios (P-4) mention role switching, not module switching
- Role switching (different position) vs module switching (different tool, same position) are distinct concepts

**Implementation Details for BUILDER**:

1. **Module Switch Flow**:
   ```dart
   Future<void> _handleModuleSelected(String moduleId) async {
     // Load new module WITHOUT invalidating session
     await _loadRuntimeHost(moduleId);

     // Session from Phase 1 login remains active
     // WebView already has scoped session token
     // New module inherits same session context
   }
   ```

2. **WebView Cleanup**: Clear WebView content but preserve session
   ```dart
   void _handleBackToModuleSelection() {
     setState(() {
       _showModuleSelection = true;
       _selectedModuleId = null;
     });

     // Clear WebView HTML but don't invalidate session
     _webViewController.loadHtmlString('<html><body></body></html>');
   }
   ```

3. **Logout Invalidates Session** (existing behavior, no change):
   ```dart
   Future<void> _handleLogout() async {
     await _authService.logout();
     _shellBridge.clearPosition();
     // Session invalidated here, as in Phase 1
   }
   ```

**Security Note**:
- Module-to-module switching happens WITHIN same position scope
- Session already scoped to position (Phase 1 design)
- Both modules operate under same position privileges
- If user changes position (future role-switch feature), THAT should invalidate session (Phase 4+)

**Document for Future**:
- Phase 4 role switching should call `_sessionBroker.invalidateSession()` before new position
- Phase 4 can implement fresh bootstrap on role change (not module change)
- Consider adding module-level access tokens if modules need different permissions within same position

---

### UNCLEAR-5: Number of Example Modules

**Decision**: Create 3 example modules (warehouse, inventory, quality)

**Rationale**:
- 2 modules is minimum to prove selection works
- 3 modules better demonstrates:
  - Grid layout behavior with odd number of items
  - Scrolling if needed (depending on screen size)
  - Sorting by displayName (3-item list shows alphabetical order clearly)
  - User can distinguish between modules more easily with 3 options
- POC scenarios reference Warehouse, Quality, and Production Supervisor modules
- Minimal additional effort (1 hour for third module as per plan)
- Inventory + Quality modules align with POC scenario categories
- 3 modules still stays within POC scope (not over-engineering)

**Implementation Details for BUILDER**:

1. **Update Mock Registry** to include 3 modules:
   ```dart
   final mockRegistryJson = {
     'modules': [
       {
         'moduleId': 'sample-warehouse',
         'displayName': 'Warehouse Clerk',
         'description': 'Receive goods against purchase orders and scan item barcodes',
         'categoryId': 'warehouse',
         // ... rest of fields
       },
       {
         'moduleId': 'sample-inventory',
         'displayName': 'Inventory Manager',
         'description': 'Count inventory and reconcile stock levels',
         'categoryId': 'inventory',
         // ... rest of fields
       },
       {
         'moduleId': 'sample-quality',
         'displayName': 'Quality Inspector',
         'description': 'Perform inspections and capture defect photos',
         'categoryId': 'quality',
         // ... rest of fields
       },
     ],
   };
   ```

2. **Create 3 React Module Files**:
   - `src/modules/sample-warehouse/index.html` (already exists, reuse)
   - `src/modules/sample-inventory/index.html` (new, as per plan template)
   - `src/modules/sample-quality/index.html` (new, similar to inventory)

3. **Distinct Visual Themes**:
   - Warehouse: Blue gradient (existing)
   - Inventory: Purple gradient (as per plan template)
   - Quality: Green gradient (new, distinct from others)

4. **Material Icons** (per UNCLEAR-1 decision):
   - Warehouse: `Icons.warehouse`
   - Inventory: `Icons.inventory_2`
   - Quality: `Icons.verified`

**Acceptance Criteria Update**:
- Change "at least 2 module cards" to "3 module cards" in AC-3.5.1
- Test module selection with all 3 modules in integration tests

---

## Edge Cases Identified

The BUILDER must handle these specific edge cases:

### 1. Rapid Module Switching
**Scenario**: User rapidly taps different module cards before first module finishes loading
**Handling**:
- Disable card taps while `_isLoading == true`
- Show loading indicator on selected card
- Prevent concurrent module load attempts

### 2. Empty Registry
**Scenario**: Registry loads successfully but contains zero modules
**Handling**:
- Display "No modules available" message (already in plan)
- Provide "Retry" button to reload registry
- Do not crash or show blank screen

### 3. Back Navigation During Module Load
**Scenario**: User taps back button while module is still loading
**Handling**:
- Cancel in-flight module load if possible
- Return to module selection screen
- Clear loading state
- Allow user to select different module

### 4. Module Load Failure After Selection
**Scenario**: Module fails to load (network error, cache miss, verification failure)
**Handling**:
- Display error message in status bar
- Keep `_showModuleSelection = true` so user sees selection screen
- Do not leave user on blank WebView
- Provide retry option or allow selecting different module

### 5. Session Expiry During Module Selection
**Scenario**: User stays on module selection screen long enough for session to expire
**Handling**:
- Module load will fail with session error
- Display error message
- Optionally auto-logout and return to login screen
- Document as known issue if complex to handle in POC

### 6. Module Selection After Offline Login
**Scenario**: User logs in while offline (Phase 3 support), sees module selection
**Handling**:
- Show all modules (per UNCLEAR-3 decision)
- Only cached modules will load successfully
- Uncached modules fail with "not available offline" error
- User can retry after connectivity restored

### 7. Very Long Module Names or Descriptions
**Scenario**: Registry contains modules with excessive displayName/description length
**Handling**:
- Use `maxLines` and `overflow: TextOverflow.ellipsis` (already in plan)
- Test with 100+ character strings
- Ensure card layout doesn't break

### 8. Registry Load Failure on First Launch
**Scenario**: App launches, user logs in, registry fails to load
**Handling**:
- Display error state in ModuleSelectionScreen
- Show "Retry" button
- Allow user to retry registry load
- Fallback: If registry never loads, block module selection (cannot proceed)

---

## Updated File Manifest

### Files to Modify (2 files)

| File Path | Changes | Complexity | Size Estimate |
|-----------|---------|------------|---------------|
| `src/shell/lib/modules/module_registry.dart` | Add `displayName`, `description`, `iconUrl?`, `categoryId?` fields to ModuleMetadata; update `_loadMockRegistry()` with 3 modules; add `getModulesForSelection()` method | Medium | +100 lines |
| `src/shell/lib/main.dart` | Add selection state vars; modify `_handleLogin()` to show selection; add `_handleModuleSelected()` callback; update `_loadRuntimeHost(moduleId)` signature; add back navigation; update `build()` and `_buildMainContent()` | High | +150 lines |

### Files to Create (4 files)

| File Path | Purpose | Complexity | Size Estimate |
|-----------|---------|------------|---------------|
| `src/shell/lib/screens/module_selection_screen.dart` | Card-based module selection UI with grid layout, loading/error states, retry logic | Medium | ~300 lines |
| `src/modules/sample-inventory/index.html` | Second example React module with purple theme, inventory counting UI | Low | ~150 lines |
| `src/modules/sample-quality/index.html` | Third example React module with green theme, quality inspection UI | Low | ~150 lines |
| `phases/phase-3.5-multi-module-selection/validator/validated.md` | This validation report | Low | This file |

### Supporting Documentation

| File Path | Purpose |
|-----------|---------|
| `phases/phase-3.5-multi-module-selection/planner/plan.md` | Original plan (already exists) |
| `README.md` or `docs/phase-3.5-summary.md` | Update with Phase 3.5 flow (post-implementation) |

**Total New Code**: ~750 lines
**Total Modified Code**: ~250 lines
**Estimated Effort**: 10-13 hours (within plan estimate)

---

## Finalized Acceptance Criteria

### AC-3.5.1: Module Selection Screen Display
**Given** user has successfully authenticated
**When** authentication completes
**Then** user sees a card-based module selection screen with 3 module cards

**Verification**:
- Login with demo credentials (e.g., `warehouse-clerk` / `password123`)
- Observe screen shows "Select Position Module" title in AppBar
- Observe exactly 3 cards are visible: Warehouse Clerk, Inventory Manager, Quality Inspector
- Each card shows displayName (large text), description (2-3 lines), version badge ("v1.0.0")
- Each card shows distinct Material icon (warehouse, inventory_2, verified)

**Pass Criteria**: All 3 cards render correctly with all metadata fields populated

---

### AC-3.5.2: Registry Contains Multiple Modules
**Given** the mock registry is loaded
**When** `getModulesForSelection()` is called
**Then** registry returns exactly 3 distinct modules with display metadata

**Verification**:
- Unit test: Load mock registry via `loadRegistry('mock://registry')`
- Call `getModulesForSelection()` and verify result count == 3
- Verify each module has non-empty `displayName` and `description`
- Verify modules are sorted alphabetically by `displayName`: Inventory Manager, Quality Inspector, Warehouse Clerk

**Pass Criteria**: Test passes, returns 3 modules in correct sort order

---

### AC-3.5.3: Module Card Selection
**Given** module selection screen is displayed
**When** user taps a module card
**Then** the selected module begins loading

**Verification**:
- Tap on "Warehouse Clerk" card
- Observe status bar message changes to "Loading module: sample-warehouse"
- Observe loading indicator appears (CircularProgressIndicator or similar)
- Observe cards become disabled/non-tappable during load

**Pass Criteria**: Loading state activates immediately on tap, prevents double-tap

---

### AC-3.5.4: WebView Loads Selected Module
**Given** user has selected a module
**When** module loading completes
**Then** WebView displays the correct React module for the selected moduleId

**Verification**:
- Test 1: Select "Warehouse Clerk" → verify WebView shows blue gradient warehouse UI
- Test 2: Tap back button → return to selection
- Test 3: Select "Inventory Manager" → verify WebView shows purple gradient inventory UI
- Test 4: Tap back button → return to selection
- Test 5: Select "Quality Inspector" → verify WebView shows green gradient quality UI
- Confirm each module has distinct visual appearance and content

**Pass Criteria**: All 3 modules load correctly with distinct UIs, no rendering errors

---

### AC-3.5.5: Back Navigation to Selection
**Given** a module is loaded in WebView
**When** user taps the back button
**Then** module selection screen reappears

**Verification**:
- Load any module (e.g., Warehouse Clerk)
- Observe back button (arrow icon) in position info bar
- Tap back button
- Verify module selection screen is shown again with all 3 cards
- Verify WebView area is cleared (no residual content)
- Verify can select and load a different module

**Pass Criteria**: Back navigation works without errors, WebView clears properly

---

### AC-3.5.6: Selection State Clears on Logout
**Given** a module is selected and loaded
**When** user logs out
**Then** all module selection state is cleared

**Verification**:
- Select and load "Inventory Manager" module
- Tap logout button
- Observe login screen appears
- Log in again with same credentials
- Verify module selection screen appears (not auto-loading Inventory Manager)
- Verify no previous selection is remembered
- Verify `_selectedModuleId` is null after logout

**Pass Criteria**: Logout clears all state, next login shows selection screen

---

### AC-3.5.7: Module Metadata Display
**Given** module cards are rendered
**When** user views the selection screen
**Then** each card displays: displayName, description, version, and Material icon

**Verification**:
- Visually inspect each of 3 cards
- Warehouse Clerk card:
  - Icon: Warehouse icon (building/box shape)
  - Display Name: "Warehouse Clerk" (large, bold)
  - Description: "Receive goods against purchase orders and scan item barcodes" (smaller text, wraps if needed)
  - Version: "v1.0.0" (small gray text, bottom-right)
- Inventory Manager card: Similar structure, purple inventory icon
- Quality Inspector card: Similar structure, green verified icon

**Pass Criteria**: All metadata fields render correctly, text truncates gracefully with ellipsis if too long

---

### AC-3.5.8: Error Handling for Missing/Failed Module
**Given** user selects a module
**When** the module cannot be loaded (not in registry, download fails, or offline without cache)
**Then** error message is displayed and user can retry or select different module

**Verification**:
- Test 1 (Empty Registry):
  - Mock `getModulesForSelection()` to return empty list
  - Verify "No modules available" message displays
  - Verify "Retry" button is present
- Test 2 (Load Failure):
  - Select a module
  - Simulate network error during `_loadRuntimeHost()`
  - Verify error message displays in status bar
  - Verify selection screen remains visible (not stuck on blank WebView)
  - Verify user can select different module
- Test 3 (Offline Uncached Module):
  - Enable airplane mode
  - Select module that is not cached
  - Verify "Module not available offline" error displays
  - Verify user can select different (cached) module

**Pass Criteria**: All error scenarios handled gracefully, no crashes, user can recover

---

### AC-3.5.9: Module Selection Works Offline (with cached modules)
**Given** user has previously loaded modules while online (modules are cached)
**When** user logs in while offline and sees module selection
**Then** cached modules load successfully when selected

**Verification**:
- Online: Load "Warehouse Clerk" module (gets cached)
- Logout
- Enable airplane mode
- Login (Phase 3 offline login support)
- Observe module selection screen with 3 modules
- Select "Warehouse Clerk"
- Verify module loads from cache successfully
- Select "Inventory Manager" (not cached)
- Verify error: "Module not available offline"

**Pass Criteria**: Cached modules load offline, uncached modules fail gracefully

---

### AC-3.5.10: Grid Layout Responsive Behavior
**Given** module selection screen is displayed on different screen sizes
**When** screen width changes (phone vs tablet)
**Then** grid adapts responsively (1 column on phone, 2 columns on tablet)

**Verification**:
- Test on phone emulator (360dp width): Verify single column layout
- Test on tablet emulator (800dp width): Verify two-column layout
- Verify `SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 400)` creates responsive grid
- Verify cards maintain aspect ratio and don't overflow

**Pass Criteria**: Grid layout adapts to screen size, no visual breakage

---

## Additional Constraints for BUILDER

### Security and Trust Boundary
1. **Session Handling**: Module switching does NOT invalidate session (per UNCLEAR-4 decision)
2. **WebView Clear**: When returning to selection screen, clear WebView with `loadHtmlString('<html><body></body></html>')` to prevent module residue
3. **Bridge Access**: All modules receive same bridge access (no module-specific permissions yet)
4. **Position Scope**: All modules operate within same position scope established at login

### Performance
1. **Module Load Time**: Target < 1s for cached modules (existing Phase 3 behavior)
2. **Grid Rendering**: Must render 3 cards without visible lag
3. **State Updates**: Use `setState()` properly to avoid unnecessary rebuilds

### User Experience
1. **Loading Indicators**: Show loading state during module load, disable cards during load
2. **Error Recovery**: Always provide path back to selection screen on error
3. **Status Messages**: Clear, actionable status bar messages (not technical jargon)
4. **Visual Distinction**: Each module must have visually distinct appearance (color scheme, icon)

### Code Quality
1. **No Hardcoding**: Module list comes from registry, not hardcoded in UI
2. **Type Safety**: Use strong typing for ModuleMetadata, avoid dynamic/any
3. **Error Handling**: Try-catch around async operations, display user-friendly errors
4. **Testing**: Write unit tests before integration tests, test edge cases

### Scope Discipline
1. **DO NOT** implement position-based filtering (out of scope per UNCLEAR-2)
2. **DO NOT** implement module search or categories (out of scope)
3. **DO NOT** implement recently used / favorites (out of scope)
4. **DO NOT** add module update notifications in UI (Phase 3 handles in background)
5. **DO NOT** over-engineer card UI (simple Material cards sufficient)

---

## Test Commands

### Unit Tests
```bash
# Test module registry enhancements
flutter test test/modules/module_registry_test.dart

# Test module selection screen (new file)
flutter test test/screens/module_selection_screen_test.dart

# Test module card widget (new file)
flutter test test/widgets/module_card_test.dart
```

### Widget Tests
```bash
# Run all widget tests including new ModuleCard tests
flutter test test/widgets/
```

### Integration Tests
```bash
# Run Phase 3.5 module selection flow test (new file)
flutter test integration_test/module_selection_flow_test.dart

# Run all integration tests (verify no regression)
flutter test integration_test/
```

### Manual Testing
```bash
# Run shell app in debug mode
cd src/shell
flutter run

# Test flow:
# 1. Login → See module selection (3 cards)
# 2. Tap Warehouse → See warehouse module
# 3. Back → See selection
# 4. Tap Inventory → See inventory module
# 5. Back → See selection
# 6. Tap Quality → See quality module
# 7. Logout → Login → Verify selection screen appears (not auto-loaded)
```

### Regression Testing
```bash
# Verify Phase 1/2/3 tests still pass
flutter test test/auth/
flutter test test/modules/
flutter test test/offline/
```

---

## Validation Status

**APPROVED**

### Rationale for Approval

1. **Plan Quality**: Well-structured, comprehensive, and appropriately scoped for POC
2. **UNCLEAR Items Resolved**: All 5 items have specific, actionable decisions aligned with POC goals
3. **Scope Discipline**: Plan correctly marks features as out-of-scope (filtering, search, favorites)
4. **Integration**: Builds on Phase 1/2/3 without breaking existing functionality
5. **Technical Approach**: Sound architecture, reuses existing registry infrastructure
6. **Acceptance Criteria**: Testable and complete (10 ACs defined above)
7. **Effort Estimate**: Realistic (10-13 hours including testing)
8. **Risk Management**: Low-risk changes, appropriate error handling

### No Blocking Issues Identified

The plan is ready for BUILDER execution with the decisions documented above.

---

## Handoff to BUILDER

### Execution Order

Follow this sequence for implementation:

**Step 1**: Extend Module Registry (2 hours)
- Add display fields to `ModuleMetadata` class
- Update `_loadMockRegistry()` with 3 modules (warehouse, inventory, quality)
- Add `getModulesForSelection()` method
- Write unit tests for new functionality

**Step 2**: Create Module Selection UI (3 hours)
- Create `module_selection_screen.dart` with `ModuleSelectionScreen` widget
- Create `ModuleCard` widget with Material icon support
- Implement grid layout with loading/error states
- Write widget tests

**Step 3**: Update Main.dart Navigation (3 hours)
- Add state variables: `_showModuleSelection`, `_selectedModuleId`
- Modify `_handleLogin()` to show selection screen
- Add `_handleModuleSelected(moduleId)` callback
- Update `_loadRuntimeHost()` to accept `moduleId` parameter
- Update `build()` and `_buildMainContent()` methods
- Add back navigation with `_handleBackToModuleSelection()`
- Update `_handleLogout()` to clear selection state

**Step 4**: Create Example Modules (2 hours)
- Reuse existing `sample-warehouse/index.html`
- Create `sample-inventory/index.html` (purple theme, counting UI)
- Create `sample-quality/index.html` (green theme, inspection UI)
- Test each module loads in WebView

**Step 5**: Integration Testing (2-3 hours)
- Write `module_selection_flow_test.dart`
- Test full flow: login → select → load → back → select different → logout
- Test offline scenarios
- Test error scenarios
- Manual end-to-end testing

**Step 6**: Regression Testing (1 hour)
- Run all Phase 1/2/3 tests
- Fix any breakage
- Verify no degradation in existing functionality

### Key Implementation Notes

1. **Material Icons per UNCLEAR-1**:
   - Warehouse: `Icons.warehouse`
   - Inventory: `Icons.inventory_2`
   - Quality: `Icons.verified`

2. **No Position Filtering per UNCLEAR-2**:
   - `getModulesForSelection()` returns ALL modules
   - No filtering logic based on position

3. **Offline Handling per UNCLEAR-3**:
   - Show all modules in selection screen
   - Let module load fail if not cached
   - Display error message on failure

4. **Session Handling per UNCLEAR-4**:
   - Keep same session when switching modules
   - Only invalidate on logout (existing behavior)

5. **Three Modules per UNCLEAR-5**:
   - Create warehouse, inventory, AND quality modules
   - Update mock registry with all 3

### Success Criteria Checklist

BUILDER should verify all 10 acceptance criteria pass before marking phase complete:
- [ ] AC-3.5.1: Module selection screen displays 3 cards
- [ ] AC-3.5.2: Registry returns 3 modules sorted correctly
- [ ] AC-3.5.3: Tapping card initiates loading
- [ ] AC-3.5.4: All 3 modules load with distinct UIs
- [ ] AC-3.5.5: Back navigation returns to selection
- [ ] AC-3.5.6: Logout clears selection state
- [ ] AC-3.5.7: All metadata displays correctly on cards
- [ ] AC-3.5.8: Error handling works for all scenarios
- [ ] AC-3.5.9: Offline cached modules load successfully
- [ ] AC-3.5.10: Grid layout responsive on different screen sizes

---

**END OF VALIDATION REPORT**
