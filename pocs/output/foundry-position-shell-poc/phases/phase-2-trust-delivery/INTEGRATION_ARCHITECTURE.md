# Phase 2 Integration Architecture

## System Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                      Foundry Position Shell                      │
│                     (Flutter Mobile App)                         │
│                                                                   │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                    main.dart (Entry Point)                  │ │
│  │                                                              │ │
│  │  Phase 1 Services          Phase 2 Services                 │ │
│  │  ├─ MockAuthService         ├─ ModuleRegistry               │ │
│  │  ├─ PositionResolver        ├─ ModuleCache                  │ │
│  │  ├─ SessionBroker           ├─ ModuleVerifier               │ │
│  │  └─ ShellBridge             ├─ FallbackManager              │ │
│  │                              ├─ ModuleUpdater                │ │
│  │                              └─ ModuleBridgeExtension        │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                   │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                      WebView Container                      │ │
│  │                                                              │ │
│  │  ┌──────────────────────────────────────────────────────┐  │ │
│  │  │              Runtime Host (HTML/JS)                   │  │ │
│  │  │                                                        │  │ │
│  │  │  ┌──────────────────────────────────────────────┐    │  │ │
│  │  │  │         Position Module (React)              │    │  │ │
│  │  │  │      (e.g., sample-warehouse v1.0.0)         │    │  │ │
│  │  │  └──────────────────────────────────────────────┘    │  │ │
│  │  │                                                        │  │ │
│  │  └──────────────────────────────────────────────────────┘  │ │
│  └────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

## Integration Flow

### 1. App Startup Sequence

```
App Launch
    ├─> initState()
    │   ├─> _initializeWebView()           [Phase 1]
    │   └─> _initializeServicesAsync()     [Phase 1 + Phase 2]
    │       │
    │       ├─> Initialize Phase 1 Services
    │       │   ├─> MockAuthService
    │       │   ├─> PositionResolver
    │       │   └─> SessionBroker
    │       │
    │       ├─> Initialize Phase 2 Services
    │       │   ├─> ModuleRegistry
    │       │   ├─> ModuleCache
    │       │   ├─> ModuleVerifier
    │       │   ├─> FallbackManager
    │       │   └─> ModuleUpdater
    │       │
    │       ├─> Load Module Registry
    │       │   └─> loadRegistry('mock://registry.json')
    │       │       └─> _loadMockRegistry()
    │       │           └─> Creates sample-warehouse v1.0.0, v1.1.0
    │       │
    │       ├─> Initialize ShellBridge (Phase 1)
    │       │
    │       └─> Register ModuleBridgeExtension (Phase 2)
    │           └─> registerWithBridge()
    │
    └─> UI Ready (Login Screen)
```

### 2. Authentication & Module Load Flow

```
User Clicks Login
    ├─> Check _servicesInitialized
    │   └─> If false: Show "Services still initializing"
    │
    ├─> _handleLogin()
    │   ├─> Authenticate with MockAuthService     [Phase 1]
    │   ├─> Resolve Position                      [Phase 1]
    │   │   └─> Get user's assigned position
    │   │
    │   └─> _loadRuntimeHost()                    [Phase 1 + Phase 2]
    │       │
    │       ├─> Check Module Cache                [Phase 2]
    │       │   └─> getCachedModulePath('sample-warehouse', '1.0.0')
    │       │       ├─> If cached: Use cached module
    │       │       └─> If not: Log "would download"
    │       │
    │       ├─> Load Runtime Host HTML
    │       │   └─> Inject JavaScript bridge
    │       │
    │       └─> Display Position UI
```

## Data Flow Diagram

```
┌──────────────┐
│   User       │
└──────┬───────┘
       │ Login
       ▼
┌──────────────────────────────────────────────────────────┐
│                   MockAuthService                        │
│  • Simulates system browser auth                         │
│  • Returns shell token (never exposed to WebView)        │
└──────────────┬───────────────────────────────────────────┘
               │ Authenticated
               ▼
┌──────────────────────────────────────────────────────────┐
│                  PositionResolver                         │
│  • Determines user's position                            │
│  • Returns position metadata (org, role, permissions)    │
└──────────────┬───────────────────────────────────────────┘
               │ Position Resolved
               ▼
┌──────────────────────────────────────────────────────────┐
│                   SessionBroker                          │
│  • Generates bootstrap code                              │
│  • Creates scoped session for runtime host               │
└──────────────┬───────────────────────────────────────────┘
               │ Bootstrap Code
               ▼
┌──────────────────────────────────────────────────────────┐
│                  Runtime Host Load                        │
│  ┌────────────────────────────────────────────────────┐  │
│  │  Phase 2 Integration:                             │  │
│  │  ├─> Check ModuleCache                            │  │
│  │  │   └─> getCachedModulePath()                    │  │
│  │  │                                                 │  │
│  │  ├─> If not cached:                               │  │
│  │  │   ├─> Would download from registry             │  │
│  │  │   ├─> Would verify signature (ModuleVerifier)  │  │
│  │  │   └─> Would cache (ModuleCache)                │  │
│  │  │                                                 │  │
│  │  └─> Load Module                                  │  │
│  │      ├─> If success: Mark as last-known-good      │  │
│  │      └─> If fail: Rollback to last-known-good     │  │
│  └────────────────────────────────────────────────────┘  │
└──────────────┬───────────────────────────────────────────┘
               │ Module Mounted
               ▼
┌──────────────────────────────────────────────────────────┐
│              Position Module Running                      │
│  • Has scoped session (not shell token)                  │
│  • Can call bridge methods                               │
│  • Isolated from other modules                           │
└──────────────────────────────────────────────────────────┘
```

## Service Dependencies

```
┌─────────────────────────────────────────────────────────┐
│                    ShellBridge                          │
│              (Phase 1 + Phase 2 Combined)               │
│                                                          │
│  Phase 1 Methods:                 Phase 2 Methods:      │
│  ├─ getBootstrapCode()            ├─ checkForUpdates()  │
│  ├─ redeemBootstrap()             ├─ getAvailableModules()│
│  ├─ validateSession()             ├─ getModuleVersion() │
│  ├─ revokeSession()                └─ installModuleUpdate()│
│  ├─ getPositionContext()                                │
│  └─ unmountModule()                                     │
└─────────────────────────────────────────────────────────┘
           │                              │
           │                              │
    ┌──────▼──────┐              ┌────────▼─────────┐
    │   Phase 1   │              │    Phase 2       │
    │  Services   │              │   Services       │
    └─────────────┘              └──────────────────┘
           │                              │
    ┌──────▼──────────┐          ┌────────▼─────────────────┐
    │ • AuthService   │          │ • ModuleRegistry         │
    │ • PositionResolver│        │ • ModuleCache            │
    │ • SessionBroker │          │ • ModuleVerifier         │
    └─────────────────┘          │ • FallbackManager        │
                                 │ • ModuleUpdater          │
                                 └──────────────────────────┘
```

## Module Update Flow (Phase 2)

```
Background Check (every 4 hours)
    │
    └─> ModuleUpdater.checkForUpdates('sample-warehouse')
        │
        ├─> Query ModuleRegistry
        │   └─> Get latest version from registry
        │
        ├─> Compare with installed version
        │
        └─> If update available:
            │
            ├─> Download Module
            │   └─> ModuleDownloader
            │       ├─> HTTP GET from downloadUrl
            │       ├─> Verify checksum (SHA-256)
            │       └─> Save to temp file
            │
            ├─> Verify Signature
            │   └─> ModuleVerifier
            │       ├─> Load trusted public key
            │       ├─> Verify RSA-2048 signature
            │       └─> Return verification result
            │
            ├─> Cache Module
            │   └─> ModuleCache
            │       ├─> Atomic move to cache dir
            │       ├─> Update cache metadata
            │       └─> Run garbage collection if needed
            │
            ├─> Mark as Last-Known-Good
            │   └─> FallbackManager
            │       └─> Record version in database
            │
            └─> Notify User
                └─> Display update notification in UI
```

## Fallback Flow (Phase 2)

```
Module Load Failure
    │
    └─> FallbackManager.recordLoadFailure()
        │
        ├─> Increment failure count
        │
        ├─> Check failure threshold (3)
        │
        └─> If threshold exceeded:
            │
            ├─> getLastKnownGoodVersion()
            │   └─> Query database
            │
            ├─> Check if version in cache
            │   └─> ModuleCache.getCachedModulePath()
            │
            ├─> Load last-known-good version
            │
            └─> Notify user of rollback
```

## File Structure

```
src/shell/lib/
│
├─ main.dart                          [MODIFIED - Integration Point]
│   ├─ Imports Phase 2 services
│   ├─ Initializes Phase 2 alongside Phase 1
│   └─ Uses ModuleCache in module loading
│
├─ Phase 1 Files (Unchanged)
│   ├─ auth/
│   │   └─ mock_auth_service.dart
│   ├─ position/
│   │   └─ position_resolver.dart
│   ├─ session/
│   │   └─ session_broker.dart
│   └─ bridge/
│       └─ shell_bridge.dart
│
└─ Phase 2 Files (Integrated)
    ├─ modules/
    │   ├─ module_registry.dart       [MODIFIED - Mock registry added]
    │   ├─ module_cache.dart
    │   ├─ module_updater.dart
    │   ├─ module_downloader.dart
    │   ├─ module_manifest.dart
    │   └─ fallback_manager.dart
    ├─ security/
    │   ├─ module_verifier.dart
    │   └─ signing_keys.dart
    └─ bridge/
        └─ module_bridge_extension.dart
```

## Integration Success Metrics

✅ **Zero Breaking Changes**
- All Phase 1 code unchanged (except integration point in main.dart)
- All Phase 1 tests still pass
- Existing user flows preserved

✅ **Clean Service Initialization**
- Services initialize in correct order
- Async initialization handled properly
- Error handling in place

✅ **Logging Visibility**
- Console logs show Phase 2 activity
- Easy to debug and verify integration
- Clear phase separation in logs

✅ **Mock Mode for POC**
- No external dependencies required
- Self-contained demonstration
- Easy to test and validate

## Next Phase Preview

**Phase 3 will add:**
- Offline module loading (use cached modules when network unavailable)
- Pre-download for offline use
- Network detection and automatic switching
- Background sync when network returns

**This Phase 2 integration provides the foundation:**
- ✅ Module cache system ready
- ✅ Version tracking in place
- ✅ Fallback mechanism available
- ✅ Update orchestration prepared
