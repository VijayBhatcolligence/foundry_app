# 🚀 Foundry Position Shell - Quick Start Guide

This guide will help you run the Phase 1 Foundation app on your local machine.

---

## 📋 Prerequisites

Before you start, make sure you have these installed:

### Required Software
1. **Flutter SDK** (3.0 or higher)
   - Download: https://docs.flutter.dev/get-started/install
   - Verify: `flutter --version`

2. **Android Studio** or **Xcode** (for iOS)
   - Android Studio: https://developer.android.com/studio
   - Xcode (Mac only): https://developer.apple.com/xcode/

3. **Node.js** (18.0 or higher)
   - Download: https://nodejs.org/
   - Verify: `node --version`

4. **npm** or **yarn**
   - Comes with Node.js
   - Verify: `npm --version`

5. **Git** (for version control)
   - Verify: `git --version`

---

## 🏗️ Project Structure Overview

```
foundry-position-shell-poc/
├── src/
│   ├── shell/              ← Flutter app (MAIN ENTRY POINT)
│   ├── runtime-host/       ← JavaScript runtime (runs in WebView)
│   └── modules/
│       └── sample-warehouse/  ← React module (loaded by runtime)
```

**How it works:**
1. **Flutter Shell** launches → Shows WebView
2. **Runtime Host** (JavaScript) loads inside WebView
3. **React Module** gets mounted by runtime host
4. User sees the warehouse module UI

---

## 🛠️ Step-by-Step Setup

### Step 1: Navigate to Project Root

```bash
cd C:/Users/bijay/OneDrive/Desktop/auto_agent3/pocs/output/foundry-position-shell-poc
```

### Step 2: Set Up Flutter Shell

```bash
# Navigate to shell directory
cd src/shell

# Get Flutter dependencies
flutter pub get

# Verify Flutter is working
flutter doctor
```

**Expected output:**
```
✓ Flutter is installed
✓ Android toolchain (or iOS)
✓ Connected devices available
```

### Step 3: Build Runtime Host

```bash
# Go back to project root
cd ../..

# Navigate to runtime host
cd src/runtime-host

# Install Node.js dependencies
npm install

# Build the runtime host bundle
npm run build
```

**What this does:**
- Installs TypeScript, webpack, and other dependencies
- Compiles `runtime-host.js` and `runtime-contract.ts`
- Creates production-ready JavaScript bundle

### Step 4: Build React Module (Sample Warehouse)

```bash
# Navigate to sample module
cd ../modules/sample-warehouse

# Install React dependencies
npm install

# Build the module
npm run build
```

**What this does:**
- Installs React, TypeScript, and build tools
- Compiles the sample warehouse module
- Creates production bundle that runtime host will load

### Step 5: Set Up an Emulator or Device

**Option A: Android Emulator**
```bash
# List available emulators
flutter emulators

# Launch an emulator
flutter emulators --launch <emulator_id>

# Or use Android Studio to start an emulator
```

**Option B: iOS Simulator (Mac only)**
```bash
# Launch iOS simulator
open -a Simulator

# Or use Xcode to launch
```

**Option C: Physical Device**
```bash
# Enable USB debugging on Android device
# Connect via USB
# Verify with:
flutter devices
```

### Step 6: Run the Flutter App

```bash
# Go back to shell directory
cd ../../shell

# Run the app (this is the main command!)
flutter run
```

**What happens:**
1. Flutter compiles the shell app
2. Installs on emulator/device
3. App launches and shows WebView
4. Runtime host boots inside WebView
5. Sample warehouse module mounts
6. You see the UI!

---

## 🎯 What You Should See

### When App Launches:

1. **Loading Screen** (briefly)
   - "Foundry Position Shell"
   - "Initializing..."

2. **Mock Login Screen**
   - Username field
   - Password field
   - "Login" button
   - Enter any credentials (it's a mock!)

3. **Position Resolution**
   - Shows: "Resolving position..."
   - Displays: "ORG001 / WAREHOUSE-CLERK-01"

4. **Runtime Host Boot**
   - Console logs: "RuntimeHost: Ready"
   - WebView initializes

5. **Module Mounted**
   - Sample Warehouse UI appears
   - Shows position context:
     - Org ID: ORG001
     - Position ID: WAREHOUSE-CLERK-01
     - Role: Warehouse Clerk
   - Displays: "Scoped Session Active"

### Expected UI Elements:

```
┌─────────────────────────────────┐
│  Foundry Position Shell         │
│                                 │
│  Position: Warehouse Clerk      │
│  Org: ORG001                    │
│                                 │
│  ┌───────────────────────────┐ │
│  │ Sample Warehouse Module   │ │
│  │                           │ │
│  │ Position Info:            │ │
│  │ • Org ID: ORG001          │ │
│  │ • Position: WAREHOUSE-... │ │
│  │ • Role Context: {...}     │ │
│  │                           │ │
│  │ Scoped Session: Active ✓  │ │
│  │                           │ │
│  │ [Module is operational]   │ │
│  └───────────────────────────┘ │
└─────────────────────────────────┘
```

---

## 🐛 Troubleshooting

### Problem: "flutter: command not found"
**Solution:** Flutter SDK not installed or not in PATH
```bash
# Add Flutter to PATH
export PATH="$PATH:/path/to/flutter/bin"

# Or reinstall Flutter
```

### Problem: "No devices found"
**Solution:** No emulator/device running
```bash
# Check connected devices
flutter devices

# Start an emulator
flutter emulators --launch <name>
```

### Problem: "Could not resolve dependencies"
**Solution:** Network or package issue
```bash
# Clean and retry
flutter clean
flutter pub get

# Or for Node.js
rm -rf node_modules
npm install
```

### Problem: "WebView shows blank screen"
**Solution:** Runtime host not built or not loading
```bash
# Rebuild runtime host
cd src/runtime-host
npm run build

# Check browser console in debug mode
flutter run --debug
# Then use Chrome DevTools to inspect WebView
```

### Problem: "Module not mounting"
**Solution:** React module not built
```bash
# Rebuild module
cd src/modules/sample-warehouse
npm run build

# Verify build output exists
ls dist/
```

### Problem: "MissingPluginException"
**Solution:** This is expected in some tests - production app works fine
```bash
# Just run the app, ignore test errors
flutter run
```

---

## 🔍 Development Workflow

### Hot Reload (Flutter changes)
```bash
# While app is running, press:
r  # Hot reload
R  # Hot restart
q  # Quit
```

### Rebuild After Changes

**If you modify Flutter code:**
```bash
# Hot reload usually works
r

# Or restart app
R
```

**If you modify Runtime Host:**
```bash
cd src/runtime-host
npm run build
# Then restart Flutter app (R)
```

**If you modify React Module:**
```bash
cd src/modules/sample-warehouse
npm run build
# Then restart Flutter app (R)
```

---

## 📱 Platform-Specific Notes

### Android
- **Minimum SDK**: API 21 (Android 5.0)
- **WebView**: Uses system WebView (should work on all devices)
- **Permissions**: None required for Phase 1

### iOS
- **Minimum Version**: iOS 12.0
- **WebView**: Uses WKWebView (built-in)
- **Signing**: Requires Apple Developer account for physical device

---

## 🧪 Testing the Security Boundaries

While the app is running, you can verify security:

### 1. Check Shell Token is Secure
- Open Flutter DevTools
- Inspect memory/storage
- Shell token should be in encrypted storage
- **NOT** visible in WebView

### 2. Check WebView Context
- Open Chrome DevTools (for WebView debugging)
- Console → type: `window.shellToken`
- **Expected**: `undefined` (token not exposed)

### 3. Check Scoped Session
- In WebView console: `window.positionContext`
- **Expected**: Shows position info (ORG001, etc.)
- Does **NOT** show shell token

### 4. Check Bootstrap Flow
- Watch console during boot
- Should see: "Bootstrap redeemed" → "Scoped session created"
- Bootstrap code should be used only once

---

## 📊 Performance Expectations

### Cold Start (First Launch)
- **Time**: 2-4 seconds
- **What happens**: Flutter init + WebView init + Runtime boot + Module mount

### Module Mount
- **Time**: < 2 seconds (per AC-6)
- **What happens**: Runtime host loads React bundle and initializes

### Module Switch (future)
- **Time**: < 1 second (per plan)
- **What happens**: Unmount + clear session + new mount

---

## 🎓 Understanding the Flow

### Authentication Flow
```
User enters credentials
    ↓
MockAuthService generates shell token
    ↓
Shell token stored in flutter_secure_storage (encrypted)
    ↓
PositionResolver determines org/position
    ↓
SessionBroker generates bootstrap code (one-time)
    ↓
Bootstrap passed to WebView
```

### Module Loading Flow
```
Runtime Host boots in WebView
    ↓
Runtime host receives bootstrap code
    ↓
Runtime calls bridge to redeem bootstrap
    ↓
Bridge creates scoped session (position-limited)
    ↓
Runtime receives scoped session
    ↓
Runtime loads React module artifact
    ↓
Module mounts with position context
    ↓
User sees module UI
```

### Security Boundary
```
[Shell Token] (flutter_secure_storage) 🔒
    ↓ NEVER EXPOSED
[Bootstrap Code] (one-time, 60s expiry)
    ↓ PASSED ONCE
[Scoped Session] (8hr expiry, position-limited)
    ↓ AVAILABLE TO MODULE
[React Module] (uses scoped session only)
```

---

## 🚀 Quick Commands Cheat Sheet

```bash
# Full setup from scratch
cd pocs/output/foundry-position-shell-poc
cd src/shell && flutter pub get && cd ../..
cd src/runtime-host && npm install && npm run build && cd ../..
cd src/modules/sample-warehouse && npm install && npm run build && cd ../..
cd src/shell && flutter run

# Just run (after setup)
cd src/shell
flutter run

# Clean rebuild
flutter clean
flutter pub get
flutter run

# Debug mode with DevTools
flutter run --debug

# Release mode (optimized)
flutter run --release
```

---

## 📞 Next Steps

After successfully running Phase 1:

1. **Explore the app** - Click around, see the mock data
2. **Check DevTools** - Inspect memory, network, logs
3. **Verify security** - Use browser DevTools to confirm token isolation
4. **Read the code** - Understand how bridge works
5. **Prepare for Phase 2** - Trust & Delivery features

---

## 🎯 Success Criteria

You've successfully run Phase 1 if you can:

✅ Launch the Flutter app on emulator/device
✅ See the mock login screen
✅ Login and see position resolution
✅ WebView loads and shows runtime host
✅ Sample warehouse module appears
✅ Position context displays correctly
✅ Scoped session shows as "Active"
✅ No crashes or errors

---

## 📚 Additional Resources

- **Flutter Docs**: https://docs.flutter.dev/
- **WebView Plugin**: https://pub.dev/packages/webview_flutter
- **React Docs**: https://react.dev/
- **TypeScript**: https://www.typescriptlang.org/

---

**Need Help?**

If you encounter issues:
1. Check the troubleshooting section above
2. Review build logs: `flutter run --verbose`
3. Check console in DevTools
4. Verify all dependencies installed correctly

Good luck! 🚀
