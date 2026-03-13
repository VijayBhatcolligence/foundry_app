# Phase 1 Foundation — Detailed Implementation Plan

## PHASE_ID
`phase-1-foundation`

## Phase Name
Foundation — Minimal Viable Architecture Path

## What This Phase Builds
This phase establishes the baseline three-tier architecture (Flutter shell → Web runtime host → React position module) with complete end-to-end flow from mock authentication through position resolution to module mounting, while proving the critical security boundary that prevents shell tokens from leaking to the web layer.

## Requirements Covered

From Section 6B Slice 1 (Foundation):
- **Shell launch**: Flutter app initializes and presents WebView container
- **Mock login**: System browser simulation for authentication flow
- **Position resolution**: Org/position determination logic after authentication
- **Bootstrap to scoped web session**: Shell token → scoped web session conversion
- **Runtime host boot**: Thin JavaScript infrastructure loads in WebView
- **One module mount/unmount**: Sample position module lifecycle
- **Role context passed correctly**: Position-scoped context delivered to module
- **No shell-token leakage**: Security boundary verification (critical)

## Deliverables

### 1. Flutter Shell (Native Layer)
**File**: `src/shell/lib/main.dart`
- Main application entry point
- WebView container initialization
- Secure storage for shell tokens (using flutter_secure_storage)
- Bridge API registration for host communication

**File**: `src/shell/lib/auth/mock_auth_service.dart`
- Mock system browser auth flow simulation
- Shell token generation and secure storage
- Token validation logic

**File**: `src/shell/lib/position/position_resolver.dart`
- Org/position determination logic
- Position metadata structure (orgId, positionId, roleContext)

**File**: `src/shell/lib/session/session_broker.dart`
- Bootstrap code generation (one-time-use token)
- Scoped web session creation
- Session validation endpoint for runtime host

**File**: `src/shell/lib/bridge/shell_bridge.dart`
- JavaScript channel registration
- Bridge method handlers (getBootstrapCode, validateSession, unmountModule)
- Bridge security boundaries (no shell token exposure)

### 2. Runtime Host (WebView Layer)
**File**: `src/runtime-host/index.html`
- Minimal HTML container with strict CSP headers
- Script loader for runtime host JavaScript

**File**: `src/runtime-host/runtime-host.js`
- Bootstrap redemption logic (converts bootstrap code to scoped session)
- Module mounting orchestration
- Module unmounting cleanup
- Bridge adapter (JavaScript ↔ Flutter channel)
- Module lifecycle state machine

**File**: `src/runtime-host/runtime-contract.ts`
- TypeScript interfaces for module contract
- Runtime API surface definitions
- Position context type definitions

### 3. Sample Position Module (React Layer)
**File**: `src/modules/sample-warehouse/index.tsx`
- Minimal React module entry point
- Module initialization hook
- Position context consumer
- Scoped session usage demonstration
- Unmount cleanup logic

**File**: `src/modules/sample-warehouse/components/PositionInfo.tsx`
- Display component showing received position context
- Demonstrates role context availability
- Shows scoped session is active (without exposing token)

**File**: `src/modules/sample-warehouse/package.json`
- Module dependencies (React, TypeScript)
- Build configuration for web artifact generation

### 4. Security Boundary Tests
**File**: `tests/security/token_leakage_test.dart`
- Flutter integration test verifying shell token never exposed to bridge
- JavaScript injection attack simulation
- WebView inspection verification (shell token not in WebView context)

**File**: `tests/security/session_isolation_test.dart`
- Verify scoped session is distinct from shell token
- Verify bootstrap code is one-time-use only
- Verify session cannot be escalated to shell token

**File**: `tests/security/csp_enforcement_test.dart`
- Verify strict CSP headers block unauthorized origins
- Verify navigation containment (no arbitrary redirects)
- Verify inline script blocking

### 5. Integration Tests
**File**: `tests/integration/auth_flow_test.dart`
- End-to-end mock auth flow
- Position resolution verification
- Bootstrap generation test

**File**: `tests/integration/module_lifecycle_test.dart`
- Module mount test
- Position context delivery test
- Module unmount cleanup verification

### 6. Configuration and Build Files
**File**: `src/shell/pubspec.yaml`
- Flutter dependencies (webview_flutter, flutter_secure_storage)

**File**: `src/runtime-host/package.json`
- Runtime host build dependencies

**File**: `src/runtime-host/tsconfig.json`
- TypeScript compiler configuration

## Architecture Context

### Three-Tier Boundary Model
This phase implements the foundational architecture from the parity evaluation document:

**Tier 1 - Flutter Shell (Custody Layer)**:
- Owns: Native distribution, auth tokens, org/position resolution, session brokering
- Does NOT own: Business UI
- Security role: Token custody, bridge gating

**Tier 2 - Web Runtime Host (Thin Infrastructure)**:
- Owns: Bootstrap redemption, module mount/unmount orchestration, runtime mediation
- Does NOT own: Business logic, second application shell
- Security role: CSP enforcement, origin containment, bridge adapter

**Tier 3 - React Position Module (Business Layer)**:
- Owns: Business UI and workflow logic
- Receives: Scoped session, position context
- Does NOT receive: Shell tokens, direct native access
- Security role: Contained execution environment

### Security Boundaries
1. **Shell Token Custody**: Shell tokens NEVER leave Flutter secure storage
2. **Bootstrap Isolation**: Bootstrap code is one-time-use, converts to scoped session
3. **Session Scoping**: Web session is position-scoped only, cannot access other positions
4. **Bridge Gating**: Bridge methods validate session scope before execution
5. **CSP Enforcement**: Strict Content Security Policy prevents unauthorized content
6. **Origin Containment**: Runtime host cannot navigate to arbitrary origins

## Inputs From Previous Phase
**None** — This is Phase 1 (Foundation)

## Outputs To Next Phase

### 1. Working Shell With WebView Host
**Interface**: `ShellContainer`
- **Type**: Flutter Application
- **Methods**:
  - `launchShell(): Future<void>` — Initializes shell and WebView
  - `loadRuntimeHost(String hostUrl): Future<void>` — Loads runtime host HTML

### 2. Tested Bootstrap Mechanism
**Interface**: `SessionBroker`
- **Type**: Dart Service Class
- **Methods**:
  - `generateBootstrapCode(Position position): Future<BootstrapCode>`
  - `redeemBootstrap(String bootstrapCode): Future<ScopedSession>`
  - `validateSession(String sessionId): Future<SessionValidation>`

### 3. Module Mount/Unmount API
**Interface**: `RuntimeHostAPI`
- **Type**: JavaScript Module
- **Methods**:
  - `mountModule(moduleConfig, context): Promise<void>`
  - `unmountModule(): Promise<void>`
  - `getModuleStatus(): ModuleStatus`

### 4. Verified Security Boundary
**Interface**: `SecurityBoundary`
- **Type**: Test Results Artifact
- **Validation Methods**: verifyNoShellTokenLeakage(), verifyBootstrapOneTimeUse(), verifyScopedSessionIsolation(), verifyCSPEnforcement()

## Acceptance Criteria

### AC-1: Shell Launches and Displays WebView
**test_command**:
```bash
cd pocs/output/foundry-position-shell-poc && flutter test integration_test/shell_launch_test.dart
```
**pass_condition**: Test passes with exit code 0, WebView widget is present in widget tree, WebView reports ready state

### AC-2: Mock Login Flow Completes and Stores Shell Token Securely
**test_command**:
```bash
cd pocs/output/foundry-position-shell-poc && flutter test integration_test/auth_flow_test.dart
```
**pass_condition**: Test passes, shell token stored in flutter_secure_storage, token not accessible via bridge

### AC-3: Position Resolution Returns Correct Org/Position
**test_command**:
```bash
cd pocs/output/foundry-position-shell-poc && flutter test test/position/position_resolver_test.dart
```
**pass_condition**: Position resolver returns expected orgId "ORG001", positionId "WAREHOUSE-CLERK-01", and roleContext contains expected fields

### AC-4: Bootstrap Creates Scoped Web Session (No Shell Token in Web Layer)
**test_command**:
```bash
cd pocs/output/foundry-position-shell-poc && flutter test test/session/session_broker_test.dart && flutter test integration_test/bootstrap_flow_test.dart
```
**pass_condition**: Bootstrap code successfully redeemed for scoped session, shell token never passed to WebView

### AC-5: Runtime Host Boots Inside WebView
**test_command**:
```bash
cd pocs/output/foundry-position-shell-poc && flutter test integration_test/runtime_host_boot_test.dart
```
**pass_condition**: WebView console logs show "RuntimeHost: Ready", bridge communication established

### AC-6: Sample Module Mounts Successfully
**test_command**:
```bash
cd pocs/output/foundry-position-shell-poc && flutter test integration_test/module_mount_test.dart
```
**pass_condition**: Module mount completes within 2 seconds, module reports "mounted" status

### AC-7: Module Can Access Scoped Session
**test_command**:
```bash
cd pocs/output/foundry-position-shell-poc && flutter test integration_test/module_session_access_test.dart
```
**pass_condition**: Module receives PositionContext with valid scopedSessionId, session validation returns success

### AC-8: Module Cannot Access Shell Token
**test_command**:
```bash
cd pocs/output/foundry-position-shell-poc && flutter test test/security/token_leakage_test.dart
```
**pass_condition**: All token leakage attempts fail, JavaScript attempts to access shell token return null/undefined

### AC-9: Module Unmounts Cleanly on Position Switch
**test_command**:
```bash
cd pocs/output/foundry-position-shell-poc && flutter test integration_test/module_unmount_test.dart
```
**pass_condition**: Unmount completes within 1 second, module status transitions to "unloaded", no memory leaks

### AC-10: Role Context Passed Correctly to Mounted Module
**test_command**:
```bash
cd pocs/output/foundry-position-shell-poc && flutter test integration_test/role_context_delivery_test.dart
```
**pass_condition**: Module receives roleContext matching position, context includes expected fields

## Technical Approach

### Technology Stack
- **Flutter** (3.x) with webview_flutter and flutter_secure_storage
- **JavaScript (ES6+)** with TypeScript for runtime host
- **React** (18.x) with TypeScript for sample module

### Security Model
Token Custody: Shell Token (secure storage) → Bootstrap Code → Scoped Session → Module Access

### Module Lifecycle
Mount: Bootstrap → Session → Load Module → Initialize → Mounted
Unmount: Cleanup → Unmount React → Clear Session → Unloaded

## Out Of Scope
- Real authentication (mock only)
- Real position modules (minimal sample only)
- Offline functionality
- Native device capabilities (camera, scanning, etc.)
- Module versioning/updates
- Production security hardening
- All scenarios from Slice 2-7

## Dependencies
- Flutter SDK >=3.0.0
- Node.js >=18.0.0
- React 18.x
- TypeScript 5.x

## Risks and Mitigation

### Risk 1: WebView Security Configuration Complexity
**Mitigation**: Start with strictest CSP, automated security tests, manual review

### Risk 2: Bridge API Design Evolution
**Mitigation**: Keep minimal, design with versioning, accept Phase 1 as learning exercise

### Risk 3: Bootstrap Redemption Timing Issues
**Mitigation**: Explicit ready-state handshake, timeout handling, comprehensive logging
