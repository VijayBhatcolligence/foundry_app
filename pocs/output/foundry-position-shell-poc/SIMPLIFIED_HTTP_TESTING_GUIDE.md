# SIMPLIFIED HTTP Testing Guide

## Overview

The app has been SIMPLIFIED - all bridge code removed, using pure direct HTTP from React to backend.

## What Changed

### 1. React Code (index.html)
- **REMOVED:** All `window.shellBridge` checks and calls
- **ADDED:** Simple direct `fetch()` calls to `http://192.168.0.163:3000`
- **UPDATED:** Header shows "HTTP Mode" (not "Bridge Mode")
- **UPDATED:** Connection status shows actual backend URL

### 2. Android Network Configuration
- **UPDATED:** `network_security_config.xml` - More permissive for debug
- **UPDATED:** `android/app/src/debug/AndroidManifest.xml` - Added `usesCleartextTraffic="true"`
- **ADDED:** Debug overrides for all cleartext traffic

### 3. Network Test Page
- **CREATED:** `assets/modules/sample-warehouse/network_test.html`
- Tests backend connectivity directly from WebView
- Shows detailed error messages and troubleshooting steps

## Build Output

**Debug APK Location:**
```
C:\Users\bijay\OneDrive\Desktop\auto_agent3\pocs\output\foundry-position-shell-poc\src\shell\build\app\outputs\flutter-apk\app-debug.apk
```

## Testing Steps

### Step 1: Verify Backend is Running

On your PC (192.168.0.163), start the backend:

```bash
cd C:\Users\bijay\OneDrive\Desktop\auto_agent3\pocs\output\foundry-position-shell-poc\src\backend
node server.js
```

Expected output:
```
Backend server running on http://192.168.0.163:3000
```

### Step 2: Check Device Network

**CRITICAL:** Device must be on same WiFi network as PC.

1. On Android device, go to: **Settings → WiFi**
2. Tap on connected network
3. Check IP address - should be `192.168.0.x` (same subnet as PC)
4. If not on same network, connect to correct WiFi

### Step 3: Test Backend from Device Browser

Before testing the app, test if device can reach backend:

1. Open **Chrome** on Android device
2. Navigate to: `http://192.168.0.163:3000/api/health`
3. Expected response: `{"status":"ok","timestamp":...}`

**If this fails:**
- Device not on same network
- Windows Firewall blocking port 3000
- Router has AP isolation enabled
- Backend not running

**To fix Windows Firewall:**
```powershell
# Run as Administrator
New-NetFirewallRule -DisplayName "Node Backend Port 3000" -Direction Inbound -LocalPort 3000 -Protocol TCP -Action Allow
```

### Step 4: Install and Test APK

1. Transfer APK to device:
   - Via USB: Copy to device storage
   - Via cloud: Upload to Google Drive, download on device
   - Via network: Use `adb install` command

2. Install APK on device

3. Open app

### Step 5: Test Network Connectivity

First, test network connectivity using the test page:

1. In the app, navigate to network test page
2. Tap "Run Tests"
3. All tests should show green (pass)

**Expected results:**
- ✓ Backend Health Check - Should pass
- ✓ Backend Transactions Endpoint - Should pass
- ✓ Google (HTTPS Test) - Should pass

**If tests fail:**
- Follow troubleshooting steps shown in red error boxes
- Most common issue: Device not on same network as PC

### Step 6: Test Warehouse Module

1. Navigate to sample-warehouse module
2. Check connection status in header:
   - Should show: "Connected to 192.168.0.163:3000"
   - If shows: "Cannot reach backend", backend is unreachable

3. Create a test transaction:
   - Fill in PO Number: "PO-TEST-001"
   - Fill in Vendor: "Test Vendor"
   - Add a line item:
     - SKU: "TEST-SKU"
     - Description: "Test Item"
     - Quantity: 1
     - Location: "A-01"
   - Tap "Submit Transaction"

4. Expected result:
   - Success message: "Transaction PO-TEST-001 submitted successfully"
   - Form resets to empty state

5. Check Transaction History:
   - Tap "Transaction History" tab
   - Should see submitted transaction
   - Should show all details correctly

## Architecture

### Pure HTTP Flow

```
React (WebView)
    |
    | fetch('http://192.168.0.163:3000/api/transactions')
    | Simple HTTP POST/GET
    | No bridge! No Flutter code!
    |
    v
Backend Server
(Node.js on PC)
```

### Key Points

1. **No Bridge Layer**
   - React makes direct HTTP calls
   - No Flutter code involved in transactions
   - WebView handles all network requests

2. **Network Security**
   - Debug build allows cleartext traffic
   - Network security config allows local IPs
   - Debug overrides allow all traffic

3. **Backend URL**
   - Hardcoded: `http://192.168.0.163:3000`
   - React calls this directly
   - No configuration needed

## Troubleshooting

### Problem: "Cannot reach backend"

**Check 1: Backend running?**
```bash
# On PC, should see Node server output
node server.js
```

**Check 2: Device can reach backend?**
- Open Chrome on device
- Go to: `http://192.168.0.163:3000/api/health`
- Should return JSON

**Check 3: Same network?**
- Device IP: `192.168.0.x`
- PC IP: `192.168.0.163`
- Must be same subnet

**Check 4: Windows Firewall?**
- Allow incoming connections on port 3000
- Run firewall rule command (see Step 3 above)

**Check 5: Router AP isolation?**
- Some routers prevent devices from talking to each other
- Check router settings, disable AP isolation

### Problem: "Network request failed"

This means WebView cannot make HTTP requests.

**Solution:**
1. Make sure debug APK is installed (not release)
2. Check network_security_config.xml has debug-overrides
3. Check debug/AndroidManifest.xml has usesCleartextTraffic="true"
4. Rebuild app: `flutter build apk --debug`

### Problem: HTTPS works but HTTP fails

This is a network security config issue.

**Solution:**
1. Verify network_security_config.xml allows cleartext for 192.168.0.163
2. Verify debug/AndroidManifest.xml has usesCleartextTraffic="true"
3. Rebuild debug APK

## Files Modified

### React Code
- `assets/modules/sample-warehouse/index.html`
  - Removed all bridge code
  - Added direct HTTP fetch() calls
  - Updated UI text

### Android Configuration
- `android/app/src/main/res/xml/network_security_config.xml`
  - Added debug-overrides
  - More permissive domain config

- `android/app/src/debug/AndroidManifest.xml`
  - Added usesCleartextTraffic="true"

### Testing Tools
- `assets/modules/sample-warehouse/network_test.html`
  - New network connectivity test page
  - Tests all endpoints
  - Shows detailed error messages

## Next Steps

### If Backend is Reachable (Chrome works)
1. App should work immediately
2. No code changes needed
3. Just install debug APK and test

### If Backend is Not Reachable (Chrome fails)
1. Fix network/firewall first
2. Don't modify app code
3. Problem is network, not app

### Testing Checklist

- [ ] Backend server running on PC
- [ ] Device on same WiFi as PC (192.168.0.x)
- [ ] Chrome on device can reach http://192.168.0.163:3000/api/health
- [ ] Windows Firewall allows port 3000
- [ ] Debug APK installed on device
- [ ] Network test page shows all green tests
- [ ] Warehouse module shows "Connected to 192.168.0.163:3000"
- [ ] Can submit transaction successfully
- [ ] Transaction appears in history

## Success Criteria

**Network Test Page:**
- All 3 tests pass (green)

**Warehouse Module:**
- Connection status: "Connected to 192.168.0.163:3000"
- Can submit transactions
- Transactions appear in history
- No errors in console

## Conclusion

The architecture is now SIMPLE:
- React makes direct HTTP calls
- No bridge code at all
- WebView handles networking
- Proper Android network configuration

If Chrome on device can reach the backend, the app will work.
If Chrome cannot reach the backend, fix network/firewall first.
