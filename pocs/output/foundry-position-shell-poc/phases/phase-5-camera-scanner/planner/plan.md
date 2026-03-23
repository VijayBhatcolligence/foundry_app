# Phase 5 — Camera/Scanner Integration
PHASE_ID: camera-scanner-phase-5
PLANNER_DOC_VERSION: 1.0.0
DEPENDS_ON: [phase-4-http-direct] | [none]
PROVIDES_TO: [none] | [final]

## What This Phase Builds
This phase adds native camera-based barcode/QR code scanning capability to the warehouse management app. Users will be able to scan product barcodes and location QR codes from within transaction forms to auto-fill product details, eliminating manual typing errors and increasing data entry speed. The implementation includes Flutter native scanner integration via mobile_scanner plugin, React UI scan buttons, backend product lookup API, and comprehensive camera permission handling.

## Requirements Covered
- REQ-F1: Scan product barcodes (UPC, EAN, Code 128)
- REQ-F2: Scan location QR codes
- REQ-F3: Auto-fill form fields with scanned data
- REQ-F4: Lookup product details from backend
- REQ-F5: Manual entry fallback if scan fails
- REQ-F6: Camera permission handling
- REQ-F7: Flashlight toggle for low light
- REQ-F8: Single scan mode (scan once, close camera)
- REQ-T1: Use Flutter native camera (mobile_scanner plugin)
- REQ-T2: Integrate via Flutter-React bridge
- REQ-T3: Add product lookup API endpoint
- REQ-T4: Support offline barcode detection
- REQ-T5: Handle camera permissions gracefully
- REQ-T6: Return consistent response format to React
- REQ-NF1: Scan detection time < 2 seconds
- REQ-NF2: Auto-close camera after 30 seconds timeout
- REQ-NF3: Works on Android API 21+
- REQ-NF4: Adds < 10MB to APK size
- REQ-NF5: Clear error messages for users

## Deliverables
- [ ] C:\Users\bijay\OneDrive\Desktop\auto_agent3\pocs\output\foundry-position-shell-poc\src\shell\lib\bridge\scanner_bridge_extension.dart: Flutter bridge extension for scanner methods (scanBarcode, scanQRCode)
- [ ] C:\Users\bijay\OneDrive\Desktop\auto_agent3\pocs\output\foundry-position-shell-poc\src\shell\lib\scanner\barcode_scanner_service.dart: Scanner service using mobile_scanner plugin
- [ ] C:\Users\bijay\OneDrive\Desktop\auto_agent3\pocs\output\foundry-position-shell-poc\src\shell\lib\scanner\scanner_screen.dart: Full-screen scanner UI widget with flashlight toggle
- [ ] C:\Users\bijay\OneDrive\Desktop\auto_agent3\pocs\output\foundry-position-shell-poc\src\shell\lib\scanner\permission_handler_service.dart: Camera permission request and handling service
- [ ] C:\Users\bijay\OneDrive\Desktop\auto_agent3\pocs\output\foundry-position-shell-poc\src\shell\pubspec.yaml: Updated with mobile_scanner and permission_handler dependencies
- [ ] C:\Users\bijay\OneDrive\Desktop\auto_agent3\pocs\output\foundry-position-shell-poc\src\shell\lib\main.dart: Updated to register scanner bridge extension
- [ ] C:\Users\bijay\OneDrive\Desktop\auto_agent3\pocs\output\foundry-position-shell-poc\src\shell\android\app\src\main\AndroidManifest.xml: Updated with camera permissions
- [ ] C:\Users\bijay\OneDrive\Desktop\auto_agent3\pocs\output\foundry-position-shell-poc\src\shell\assets\modules\sample-warehouse\index.html: Updated React UI with scan buttons and auto-fill logic
- [ ] C:\Users\bijay\OneDrive\Desktop\auto_agent3\pocs\output\foundry-position-shell-poc\src\backend\server.js: Updated with product lookup endpoint GET /api/products/:barcode
- [ ] C:\Users\bijay\OneDrive\Desktop\auto_agent3\pocs\output\foundry-position-shell-poc\src\backend\seed.js: Seed script with sample product data including barcodes

## Inputs From Previous Phase
- RuntimeHost: React app with transaction form at C:\Users\bijay\OneDrive\Desktop\auto_agent3\pocs\output\foundry-position-shell-poc\src\shell\assets\modules\sample-warehouse\index.html
- ShellBridge: Existing bridge infrastructure with MethodChannel at 'com.foundry.shell/bridge'
- BackendAPI: Node.js backend at http://192.168.0.163:3000 with transaction endpoints
- TransactionForm: React form with line item inputs (sku, description, quantity, location)

## Outputs To Next Phase
none

## Acceptance Criteria
- [ ] AC-5.1
      criterion: Camera opens in less than 1 second when scan button is pressed
      test_command: adb shell am start -n com.foundry.shell/.MainActivity && adb logcat -s "Scanner:*" | grep "Camera opened in"
      pass_condition: Log shows "Camera opened in XXXms" where XXX < 1000
      blocking: true

- [ ] AC-5.2
      criterion: Barcode detection completes in less than 2 seconds from scan initiation
      test_command: adb logcat -s "Scanner:*" | grep "Barcode detected:"
      pass_condition: Time between "Scan initiated" and "Barcode detected" < 2000ms
      blocking: true

- [ ] AC-5.3
      criterion: Scanned product barcode triggers backend lookup and auto-fills SKU, description, and location fields
      test_command: Manual test - scan barcode "1234567890123", verify form fields populated
      pass_condition: SKU field shows barcode value, description shows product name, location shows default warehouse location
      blocking: true

- [ ] AC-5.4
      criterion: Camera permission denied shows clear error message and maintains manual entry capability
      test_command: adb shell pm revoke com.foundry.shell android.permission.CAMERA && test scan button
      pass_condition: User sees "Camera permission denied. Please enable in settings or enter manually." message and form remains editable
      blocking: true

- [ ] AC-5.5
      criterion: Manual entry fallback works when scanner fails or user cancels
      test_command: Manual test - press scan button, press back/cancel, verify manual input still works
      pass_condition: Form fields remain editable and accept keyboard input
      blocking: true

- [ ] AC-5.6
      criterion: Flashlight toggle works in low light conditions
      test_command: Manual test - open scanner, tap flashlight icon, verify torch LED activates
      pass_condition: Device flashlight turns on/off when icon is tapped
      blocking: false

- [ ] AC-5.7
      criterion: Scanner auto-closes after 30 second timeout with clear message
      test_command: Manual test - open scanner, wait 30 seconds without scanning
      pass_condition: Scanner closes and shows "Scan timeout. Please try again or enter manually."
      blocking: true

- [ ] AC-5.8
      criterion: Bridge method scanBarcode returns consistent response format
      test_command: adb logcat -s "ShellBridge:*" | grep "scanBarcode result:"
      pass_condition: Result JSON contains {success: boolean, barcode?: string, format?: string, error?: string}
      blocking: true

- [ ] AC-5.9
      criterion: Backend product lookup API returns product details in < 500ms
      test_command: curl -w "@curl-format.txt" -s "http://192.168.0.163:3000/api/products/1234567890123"
      pass_condition: time_total < 0.5 seconds and response contains {success: true, product: {sku, name, location}}
      blocking: true

- [ ] AC-5.10
      criterion: Scanner works on Android API 21+ devices
      test_command: flutter build apk && adb -s <api21-device> install build/app/outputs/flutter-apk/app-release.apk
      pass_condition: App installs and scanner opens without crashes on API 21 device
      blocking: true

- [ ] AC-5.11
      criterion: APK size increase is less than 10MB
      test_command: ls -lh build/app/outputs/flutter-apk/app-release.apk (before and after)
      pass_condition: APK size delta < 10MB
      blocking: false

## Manual Test Steps
1. Launch app and login → Expected: Warehouse module loads successfully
2. Navigate to Create Transaction tab → Expected: Transaction form displays
3. Add line item → Expected: Empty line item row appears with scan icon buttons
4. Tap scan icon next to SKU field → Expected: Full-screen camera view opens in < 1 second
5. Point camera at product barcode (UPC/EAN/Code128) → Expected: Green detection box appears, beep sound plays
6. Barcode detected → Expected: Camera closes, SKU field auto-filled with barcode value
7. Verify product lookup → Expected: Description and location fields auto-filled from backend API
8. Tap flashlight icon in dark environment → Expected: Device flashlight toggles on/off
9. Tap scan icon, then press back button → Expected: Scanner closes, form remains editable
10. Revoke camera permission in settings, tap scan icon → Expected: Clear error message shown: "Camera permission required. Enable in settings or enter manually."
11. Manually type SKU value → Expected: Manual entry works as fallback
12. Tap scan icon, wait 30 seconds → Expected: Scanner auto-closes with timeout message
13. Scan location QR code in location field → Expected: QR code value auto-fills location field
14. Submit complete transaction → Expected: Transaction saved successfully with scanned data

## Phase Achievement
Warehouse clerks can scan product barcodes and location QR codes to auto-fill transaction forms in under 2 seconds, eliminating manual typing errors and increasing data entry speed.

## Planner Notes
⚠ UNCLEAR: Barcode format support priority - Spec mentions UPC, EAN, Code 128. mobile_scanner plugin supports many formats (QR, EAN-8, EAN-13, UPC-A, UPC-E, Code 39, Code 93, Code 128, ITF, Codabar, Aztec, Data Matrix, PDF417). Validator should confirm if we need to limit detection to specific formats or allow all supported formats for maximum flexibility.

⚠ UNCLEAR: Product database schema - Spec requires "Products table with barcodes" but doesn't specify complete schema. Assuming minimal schema: {sku: string, barcode: string, name: string, description?: string, default_location: string}. Validator should confirm additional fields needed (price, category, vendor, stock_level, etc.).

⚠ UNCLEAR: Multiple barcode support - Spec doesn't clarify behavior when multiple barcodes are in camera view simultaneously. Assuming single-scan mode that returns first detected barcode. Validator should confirm if multi-select or "best match" logic is needed.

⚠ UNCLEAR: Offline barcode detection behavior - REQ-T4 mentions "Support offline barcode detection" but spec context says "HTTP-only mode (no offline features needed for this phase)". mobile_scanner plugin performs detection locally (offline-capable) but product lookup requires network. Assuming barcode detection works offline but product lookup shows error message when offline. Validator should confirm offline UX behavior.
