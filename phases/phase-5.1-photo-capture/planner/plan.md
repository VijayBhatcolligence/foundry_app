# Phase 5.1 — Photo Capture Extension
PHASE_ID: photo-capture-phase-5.1
PLANNER_DOC_VERSION: 6.0.0
DEPENDS_ON: [camera-scanner-phase-5]
PROVIDES_TO: [final]

## What This Phase Builds

Phase 5.1 extends the existing camera capability from Phase 5 (barcode scanning) by adding native photo capture functionality for product documentation. Users can now take and attach up to 5 photos per line item to document product condition, damage, labels, or packaging during warehouse transactions. The implementation adds a Flutter photo capture service using the camera plugin, local photo storage with 30-day auto-cleanup, thumbnail generation for efficient React UI display, and a new capturePhoto() bridge method that works alongside the existing scanBarcode() method. Photos are stored locally only with no backend upload in this phase, enabling fast capture (< 3 seconds) and offline operation. The React UI displays photo thumbnails inline with line items and provides a full-resolution viewer modal with deletion capability.

## Requirements Covered

### Functional Requirements (Phase 5.1)
- REQ-F9: Capture photos of products, labels, damage, or packaging using device camera
- REQ-F10: Attach multiple photos to each line item (max 5 photos per item)
- REQ-F11: Display photo thumbnails (200x200) in line item form row
- REQ-F12: View full-resolution photo in modal overlay (click thumbnail to open)
- REQ-F13: Delete individual photos before transaction submission
- REQ-F14: Preview photo after capture with confirm/retake options
- REQ-F15: Store photos locally with 30-day retention policy

### Technical Requirements (Phase 5.1)
- REQ-T7: Use Flutter camera plugin (camera: ^0.10.0) for photo capture (separate from mobile_scanner used for barcodes)
- REQ-T8: Save photos to app Documents directory (platform-specific path)
- REQ-T9: Generate thumbnails (200x200 max) for React display using image package
- REQ-T10: Return photo URI (file:// scheme) to React via bridge
- REQ-T11: Auto-cleanup photos older than 30 days on app start
- REQ-T12: Compress photos to max 1920x1080 resolution, 85% JPEG quality
- REQ-T13: Unique filenames using timestamp + UUID (collision prevention)
- REQ-T14: Reuse existing camera permission service from Phase 5

### Non-Functional Requirements (Phase 5.1)
- REQ-NF6: Photo capture time < 3 seconds (button tap to photo saved)
- REQ-NF7: Photo file size < 500KB after compression
- REQ-NF8: Support up to 250 photos total per transaction (50 items × 5 photos)
- REQ-NF9: Thumbnail generation < 200ms per photo
- REQ-NF10: Photo cleanup process < 2 seconds on app start
- REQ-NF11: Photo display in React < 500ms (file:// URI loading)
- REQ-NF12: APK size increase < 5MB (camera plugin + image library)

### Preserved Requirements (Phase 5 - Must Still Pass)
- REQ-F1: Scan product barcodes (UPC, EAN, Code 128) - NO CHANGES
- REQ-F2: Scan location QR codes - NO CHANGES
- REQ-F3: Auto-fill form fields with scanned data - NO CHANGES
- REQ-F6: Camera permission handling - REUSED by photo capture

## Deliverables

### NEW Flutter Components (5 files)
- [ ] C:\Users\bijay\OneDrive\Desktop\auto_agent3\pocs\output\foundry-position-shell-poc\src\shell\lib\bridge\photo_bridge_extension.dart: Bridge extension providing capturePhoto() and deletePhoto() methods to React via MethodChannel, reuses permission service
- [ ] C:\Users\bijay\OneDrive\Desktop\auto_agent3\pocs\output\foundry-position-shell-poc\src\shell\lib\photo\photo_capture_service.dart: Encapsulates camera plugin integration for still photos, manages camera controller lifecycle, handles photo capture and compression
- [ ] C:\Users\bijay\OneDrive\Desktop\auto_agent3\pocs\output\foundry-position-shell-poc\src\shell\lib\photo\photo_capture_screen.dart: Full-screen camera preview widget with capture button, preview after capture with confirm/retake UI, flashlight toggle
- [ ] C:\Users\bijay\OneDrive\Desktop\auto_agent3\pocs\output\foundry-position-shell-poc\src\shell\lib\photo\photo_storage_service.dart: Photo file management (save, retrieve, delete), 30-day cleanup logic, thumbnail generation coordination
- [ ] C:\Users\bijay\OneDrive\Desktop\auto_agent3\pocs\output\foundry-position-shell-poc\src\shell\lib\photo\thumbnail_generator.dart: Generate 200x200 thumbnails in WebP format for efficient display, async processing

### MODIFIED Flutter Components (3 files)
- [ ] C:\Users\bijay\OneDrive\Desktop\auto_agent3\pocs\output\foundry-position-shell-poc\src\shell\lib\main.dart: Import and register photo bridge extension, set context for photo navigation
- [ ] C:\Users\bijay\OneDrive\Desktop\auto_agent3\pocs\output\foundry-position-shell-poc\src\shell\lib\bridge\shell_bridge.dart: Add capturePhoto and deletePhoto method handlers to switch statement, register photo extension
- [ ] C:\Users\bijay\OneDrive\Desktop\auto_agent3\pocs\output\foundry-position-shell-poc\src\shell\pubspec.yaml: Add camera: ^0.10.0, image: ^4.0.0, uuid: ^4.0.0, path_provider: ^2.0.0 dependencies

### MODIFIED React UI (1 file)
- [ ] C:\Users\bijay\OneDrive\Desktop\auto_agent3\pocs\output\foundry-position-shell-poc\src\shell\assets\modules\sample-warehouse\index.html: Add photo capture button (📸) next to SKU field, photo thumbnail gallery with delete buttons, photo modal viewer with full-res display and navigation, handlePhotoCapture(), handlePhotoDelete(), showPhotoModal() functions

### UNCHANGED Files (Preserve Phase 5 Functionality)
- ✅ C:\Users\bijay\OneDrive\Desktop\auto_agent3\pocs\output\foundry-position-shell-poc\src\shell\lib\bridge\scanner_bridge_extension.dart: Barcode scanning bridge - NO CHANGES
- ✅ C:\Users\bijay\OneDrive\Desktop\auto_agent3\pocs\output\foundry-position-shell-poc\src\shell\lib\scanner\barcode_scanner_service.dart: Barcode scanning service - NO CHANGES
- ✅ C:\Users\bijay\OneDrive\Desktop\auto_agent3\pocs\output\foundry-position-shell-poc\src\shell\lib\scanner\scanner_screen.dart: Barcode scanner UI - NO CHANGES
- ✅ C:\Users\bijay\OneDrive\Desktop\auto_agent3\pocs\output\foundry-position-shell-poc\src\shell\lib\scanner\permission_handler_service.dart: Camera permissions - REUSED (no code changes)
- ✅ C:\Users\bijay\OneDrive\Desktop\auto_agent3\pocs\output\foundry-position-shell-poc\src\backend\server.js: Backend server - NO CHANGES (local storage only in Phase 5.1)

## Inputs From Previous Phase

From Phase 5 (camera-scanner-phase-5):
- PermissionHandlerService: { checkCameraPermission(): Future<PermissionStatus>, requestCameraPermission(): Future<PermissionStatus> } - Reused for photo capture permission checks
- Bridge Registration Pattern: { registerWithBridge(ShellBridge), setContext(BuildContext) } - Photo bridge extension follows same pattern
- ShellBridge Method Routing: MethodChannel handler switch statement in shell_bridge.dart - Photo methods added alongside scanner methods
- Camera Permission State: Android manifest already includes <uses-permission android:name="android.permission.CAMERA" /> - No additional permissions needed
- React Bridge Interface: window.shellBridge.{methodName}() pattern established - Photo methods follow same convention

## Outputs To Next Phase

This is the final phase. Provides photo capture capability to all React modules:

**Photo Capture API** (available via shellBridge):
- window.shellBridge.capturePhoto(options?: {quality?: number, maxWidth?: number, maxHeight?: number}): Promise<{success: bool, photoUri?: string, timestamp?: number, width?: number, height?: number, fileSize?: number, error?: string}>
- window.shellBridge.deletePhoto({photoUri: string}): Promise<{success: bool, error?: string}>

**Photo Storage Structure**:
- Storage Location: {app_documents}/photos/originals/ (full-res) and {app_documents}/photos/thumbnails/ (200x200)
- Filename Format: YYYY-MM-DD_HHMMSS_{uuid8}.jpg (original) and YYYY-MM-DD_HHMMSS_{uuid8}_thumb.webp (thumbnail)
- Retention Policy: Photos older than 30 days auto-deleted on app start

**React Data Model Pattern** (for other modules):
- Line Item Photos Array: lineItems[i].photos = [{uri: "file://...", timestamp: number, caption?: string}]
- Max Photos Per Item: 5 photos enforced by bridge (returns error if exceeded)
- Photo Display: Thumbnails shown inline, modal for full-resolution view

## Acceptance Criteria

### Photo Capture Flow (Primary Features)

- [ ] AC-5.1.1
      criterion: Photo button opens camera in less than 2 seconds when pressed
      test_command: adb logcat -s "PhotoCapture:*" | grep "Camera opened in"
      pass_condition: Log shows "Camera opened in XXXms" where XXX < 2000
      blocking: true

- [ ] AC-5.1.2
      criterion: User can take photo and see preview screen immediately after capture
      test_command: Manual test - tap photo button (📸), take photo, verify preview shows captured image with Confirm/Retake buttons
      pass_condition: Preview displays within 500ms of capture button press, image visible, both action buttons present
      blocking: true

- [ ] AC-5.1.3
      criterion: User can confirm or retake photo from preview screen
      test_command: Manual test - capture photo, tap Retake button, verify camera returns to capture mode; then capture again, tap Confirm, verify returns to form
      pass_condition: Retake returns to live camera view, Confirm closes camera and returns photoUri
      blocking: true

- [ ] AC-5.1.4
      criterion: Confirmed photo attaches to correct line item with valid photoUri and timestamp
      test_command: Manual test - add 2 line items, capture photo for item 1, verify lineItems[0].photos contains entry, capture for item 2, verify lineItems[1].photos contains entry
      pass_condition: React state shows {uri: "file://...", timestamp: number} in correct array, URIs are unique
      blocking: true

- [ ] AC-5.1.5
      criterion: Photo thumbnail displays in line item row within 1 second after capture
      test_command: Manual test - capture photo, measure time until thumbnail appears in UI
      pass_condition: Thumbnail image (200x200) visible in line item row, renders < 1 second, clickable
      blocking: true

### Photo Management (Storage and Limits)

- [ ] AC-5.1.6
      criterion: User can capture up to 5 photos per line item, 6th attempt shows error
      test_command: Manual test - capture 5 photos for one line item (thumbnails show 1-5), attempt 6th capture
      pass_condition: Photos 1-5 succeed with thumbnails shown, 6th attempt returns {success: false, error: "Maximum 5 photos per item"}
      blocking: true

- [ ] AC-5.1.7
      criterion: User can delete individual photos via delete button, removes from storage and UI
      test_command: Manual test - capture 3 photos, click delete (🗑️) on 2nd photo, verify thumbnail removed; check adb shell ls {photos_dir} to confirm file deleted
      pass_condition: Thumbnail disappears from UI, React state updated (photos.length === 2), original and thumbnail files deleted from storage
      blocking: true

- [ ] AC-5.1.8
      criterion: User can click thumbnail to view full-resolution photo in modal
      test_command: Manual test - capture photo, click thumbnail, verify modal opens showing full-res image with close button
      pass_condition: Modal displays full photo (not thumbnail), close button works, modal dismissible
      blocking: true

- [ ] AC-5.1.9
      criterion: Photos persist in React state across tab switches until page reload
      test_command: Manual test - capture 2 photos, switch to History tab, return to Create tab, verify photos still visible
      pass_condition: Photo thumbnails remain in line item, React state unchanged after tab navigation
      blocking: true

- [ ] AC-5.1.10
      criterion: Photos older than 30 days are auto-deleted on app start
      test_command: Manual test - create test photos with timestamp 31 days ago (modify file timestamp or mock date), restart app, check adb logcat for cleanup logs and verify old files deleted
      pass_condition: Cleanup log shows "Deleted X old photos", only photos > 30 days removed, recent photos preserved
      blocking: true

### Performance Requirements

- [ ] AC-5.1.11
      criterion: Photo capture completes in less than 3 seconds from button tap to file saved
      test_command: adb logcat -s "PhotoCapture:*" | grep "Photo saved in"
      pass_condition: Log shows "Photo saved in XXXms" where XXX < 3000 (includes capture + compression + thumbnail generation)
      blocking: true

- [ ] AC-5.1.12
      criterion: Photo file size less than 500KB after compression
      test_command: adb shell ls -lh /data/data/com.foundry.shell/app_flutter/photos/originals/ | awk '{print $5, $9}'
      pass_condition: All .jpg files show size < 500K in multiple lighting conditions (bright, dim, indoor, outdoor)
      blocking: true

- [ ] AC-5.1.13
      criterion: Thumbnail generation completes in less than 200ms per photo
      test_command: adb logcat -s "Thumbnail:*" | grep "Thumbnail generated in"
      pass_condition: Log shows "Thumbnail generated in XXXms" where XXX < 200
      blocking: true

- [ ] AC-5.1.14
      criterion: Photo cleanup process completes in less than 2 seconds on app start
      test_command: Create 100 test photos (50 old, 50 recent), restart app, check adb logcat -s "PhotoStorage:*" | grep "Cleanup completed in"
      pass_condition: Log shows "Cleanup completed in XXXms" where XXX < 2000, 50 old photos deleted
      blocking: true

### Regression Tests (Phase 5 Must Still Work)

- [ ] AC-5.1.15
      criterion: Barcode scanning still works identically after photo feature added
      test_command: Manual test - tap barcode scan button (📷) next to SKU, scan barcode, verify form auto-fills with product data
      pass_condition: Barcode scanning flow unchanged from Phase 5, AC-5.3 from Phase 5 still passes
      blocking: true

- [ ] AC-5.1.16
      criterion: Camera permissions work for both scanBarcode and capturePhoto methods
      test_command: Manual test - revoke camera permission in settings, tap scan button (permission error), grant permission, tap photo button (works), tap scan button (works)
      pass_condition: Both features respect shared camera permission, both show same error message when denied
      blocking: true

- [ ] AC-5.1.17
      criterion: No interference between scanBarcode and capturePhoto operations
      test_command: Manual test - capture photo for item 1, immediately scan barcode for item 2, capture photo for item 2, scan barcode for item 3
      pass_condition: All operations complete successfully, no camera lockup, no state corruption, correct data attached to correct items
      blocking: true

### Bridge and Integration

- [ ] AC-5.1.18
      criterion: Bridge method capturePhoto returns consistent response format matching interface contract
      test_command: adb logcat -s "ShellBridge:*" | grep "capturePhoto result:"
      pass_condition: Response JSON contains {success: bool, photoUri?: string, timestamp?: number, width?: number, height?: number, fileSize?: number, error?: string}
      blocking: true

- [ ] AC-5.1.19
      criterion: APK size increase less than 5MB after adding camera and image plugins
      test_command: ls -lh build/app/outputs/flutter-apk/app-release.apk (compare Phase 5 APK vs Phase 5.1 APK)
      pass_condition: APK size delta < 5MB (camera plugin ~2-3MB, image package ~1MB, code ~500KB)
      blocking: false

## Manual Test Steps

### Regression: Phase 5 Barcode Scanning (Verify No Breakage)
1. Launch app, login, navigate to Create Transaction → Expected: Warehouse module loads
2. Add line item, tap barcode scan button (📷) → Expected: Camera opens, barcode scanning works
3. Scan product barcode → Expected: Form auto-fills SKU, Description, Location (AC-5.3 regression)
4. Verify flashlight toggle still works in scanner → Expected: Torch toggles on/off

### Phase 5.1: Photo Capture Happy Path
5. Tap photo capture button (📸) next to SKU field → Expected: Camera opens in < 2 seconds with capture button
6. Tap capture button (shutter icon) → Expected: Photo taken, preview screen shows with Confirm/Retake buttons
7. Tap Retake button → Expected: Returns to camera view
8. Capture another photo, tap Confirm → Expected: Camera closes, returns to form
9. Verify thumbnail appears in line item Photos section → Expected: 200x200 thumbnail visible < 1 second
10. Click thumbnail → Expected: Modal opens showing full-resolution photo with close button
11. Click close in modal → Expected: Modal dismisses, form visible
12. Capture 4 more photos for same line item → Expected: 5 thumbnails total displayed
13. Attempt to capture 6th photo → Expected: Error toast "Maximum 5 photos per item"
14. Click delete button (🗑️) on 3rd thumbnail → Expected: Thumbnail removed, 4 photos remain
15. Switch to History tab and back to Create → Expected: 4 photos still visible

### Photo Capture for Multiple Items
16. Add second line item, capture 2 photos for item 2 → Expected: Photos attached to correct item, item 1 still shows 4 photos, item 2 shows 2 photos
17. Verify each thumbnail opens correct photo in modal → Expected: Modal shows correct photo for clicked thumbnail

### Permission Tests
18. Revoke camera permission (Settings → Apps → Foundry Shell → Permissions → Camera → Deny)
19. Tap barcode scan button → Expected: Permission error message
20. Tap photo capture button → Expected: Same permission error message
21. Grant camera permission → Expected: Both barcode and photo features work

### Performance Tests
22. Capture photo in bright light → Expected: File size < 500KB, capture time < 3 seconds, thumbnail < 200ms
23. Capture photo in low light → Expected: File size < 500KB despite lower light
24. Capture 5 photos rapidly → Expected: All succeed, no lag, all < 3 seconds each

### Cleanup Test (Requires Manual Setup)
25. Use adb to create test photos with old timestamps (31 days ago) in photos/originals/ and photos/thumbnails/
26. Restart app → Expected: adb logcat shows "Deleted X old photos", old files removed
27. Verify recent photos preserved → Expected: Only 30+ day old photos deleted

### Edge Cases
28. Capture photo with no line items → Expected: Error or graceful handling (no crash)
29. Delete all photos from an item → Expected: Photos section empty, can capture new photos
30. Capture photo, immediately close app → Expected: Photo saved, visible on app relaunch

## Phase Achievement

Warehouse clerks can now capture and attach up to 5 photos per line item to document product condition, damage, labels, or packaging during receiving and inventory operations, with photos stored locally for 30 days and displayed as thumbnails with full-resolution viewing capability, working seamlessly alongside the existing barcode scanning feature.

## Planner Notes

### Design Decisions Made

✅ **DECIDED**: Photo storage location = Local app Documents directory only
- Rationale: Phase 5.1 focuses on capture and local management. Backend upload adds complexity (multipart upload, offline queue, retry logic) and is deferred to future Phase 5.2 for cleaner separation of concerns.

✅ **DECIDED**: Photo plugin = camera ^0.10.0 (separate from mobile_scanner)
- Rationale: mobile_scanner optimized for barcode/QR detection with hardware acceleration. camera plugin better for still photo quality with manual focus, exposure control, and higher resolution capture. Two plugins increases APK size but provides best-in-class experience for each use case.

✅ **DECIDED**: Thumbnail format = WebP (not JPEG)
- Rationale: WebP provides 30% smaller file size than JPEG at same quality, faster loading in WebView, supported by Flutter image package and modern browsers.

✅ **DECIDED**: Photo return format = photoUri (file://) only, no base64
- Rationale: file:// URI efficient for WebView display via <img src="file://...">. base64 encoding would increase response size and slow bridge communication. If future backend upload needed, bridge can add uploadPhoto() method that reads file and uploads.

✅ **DECIDED**: Photo attachment = Line item level (not transaction level or SKU level)
- Rationale: Photos document specific product instances in specific transactions (e.g., "this pallet of SKU-123 received on 2026-03-23 has damage"). Not shared across all SKU-123 instances globally.

✅ **DECIDED**: Max photos = 5 per line item
- Rationale: Covers typical documentation needs (front view, back view, label closeup, damage detail, packaging). Prevents storage abuse (50 items × 5 photos × 500KB = 125MB max per transaction is acceptable).

✅ **DECIDED**: Photo retention = 30 days with auto-cleanup on app start
- Rationale: Sufficient for transaction disputes or audits. Auto-cleanup prevents unbounded storage growth. Cleanup on app start (not background service) simplifies implementation and avoids battery/permission issues.

✅ **DECIDED**: Photo preview = YES with Confirm/Retake, Photo crop = NO
- Rationale: Preview essential for quality verification. Crop adds significant UI complexity (crop tool, aspect ratio, zoom, pan) and is out of scope for Phase 5.1. Can be added in Phase 5.3 if user feedback demands it.

✅ **DECIDED**: Bridge pattern = Follow Phase 5 scanner_bridge_extension.dart pattern
- Rationale: Proven pattern with rate limiting, permission handling, context management, error handling. Consistency across bridge extensions reduces cognitive load and bugs.

### Unclear Requirements (Validator Must Resolve)

⚠ **UNCLEAR**: Should flashlight toggle be available in photo capture screen?
- Context: Phase 5 barcode scanner has flashlight toggle (scanner_screen.dart). Photo capture may need same for low-light documentation.
- Validator Decision Required: YES (reuse flashlight pattern) or NO (rely on camera auto-exposure)
- Impact: Minor - if YES, add FloatingActionButton for torch toggle (5 lines, reuse BarcodeScannerService torch logic)

⚠ **UNCLEAR**: Should users be able to add text captions to photos?
- Context: Draft plan shows caption?: string in photo data model, but no UI specified.
- Validator Decision Required: YES (add caption text input in photo modal) or NO (photos only, no captions in Phase 5.1)
- Impact: Medium - if YES, add TextField to modal UI, persist caption in React state, display under thumbnail

⚠ **UNCLEAR**: Should photo capture work with front camera (selfie mode) or back camera only?
- Context: Barcode scanning uses back camera. Photo documentation typically uses back camera to photograph products, but some users may want front camera.
- Validator Decision Required: BACK CAMERA ONLY (like barcode scanner) or BOTH CAMERAS with toggle button
- Impact: Low - if BOTH, add camera facing toggle button (reuse pattern from camera plugin examples)

⚠ **UNCLEAR**: Photo quality setting - should users be able to adjust quality or fixed at 85%?
- Context: Technical spec says 85% JPEG quality, but some users may want higher quality (larger files) or lower (smaller files).
- Validator Decision Required: FIXED 85% (simplest) or CONFIGURABLE via settings screen
- Impact: Medium - if CONFIGURABLE, add settings UI and persist preference in shared_preferences

⚠ **UNCLEAR**: What happens to photos when transaction is submitted?
- Context: Phase 5.1 stores locally only. When user taps "Create Transaction" button, are photos kept, deleted, or uploaded?
- Validator Decision Required: KEEP (persist for 30 days), DELETE IMMEDIATELY (transaction complete = cleanup), or UPLOAD (requires backend in Phase 5.1)
- Impact: High - affects data model and storage lifecycle logic. Current assumption is KEEP for 30 days (matches retention policy).

## Dependencies

### Flutter Dependencies (Added to pubspec.yaml)

```yaml
dependencies:
  # EXISTING from Phase 5
  mobile_scanner: ^5.0.0          # Barcode/QR scanning (no changes)
  permission_handler: ^11.0.0     # Camera permissions (reused, no changes)

  # NEW for Phase 5.1
  camera: ^0.10.0                 # Still photo capture (~2-3MB APK)
  image: ^4.0.0                   # Image processing, compression, thumbnails (~1MB APK)
  uuid: ^4.0.0                    # Unique photo filenames (~50KB APK)
  path_provider: ^2.0.0           # App documents directory path (~100KB APK)
```

**Total Phase 5.1 APK Size Impact**: ~4-5MB (well under 5MB requirement)

### Reused Phase 5 Components

- lib/scanner/permission_handler_service.dart: Camera permission checks (checkCameraPermission, requestCameraPermission methods reused)
- Bridge registration pattern: registerWithBridge(ShellBridge) and setContext(BuildContext) established by scanner_bridge_extension.dart
- Android manifest camera permission: <uses-permission android:name="android.permission.CAMERA" /> already declared
- ShellBridge method routing: Switch statement handler in shell_bridge.dart _handleMethodCall method

## Risk Assessment

| Risk | Severity | Likelihood | Mitigation |
|------|----------|------------|------------|
| camera plugin conflicts with mobile_scanner plugin | MEDIUM | LOW | Separate plugins with separate controllers, separate screen widgets, separate bridge methods. Integration test AC-5.1.17 validates no interference. |
| Photo storage fills device disk | MEDIUM | MEDIUM | 30-day retention policy, 500KB max per photo, 5 photos per item limit, auto-cleanup on app start. Max storage: 50 items × 5 photos × 500KB × 30 days = ~3.75GB worst case (acceptable). |
| Thumbnail generation blocks UI thread | LOW | LOW | Use async compute() for image processing, target < 200ms per thumbnail (AC-5.1.13 validates). Image package uses native code (fast). |
| file:// URI not loading in React WebView | LOW | LOW | Standard WebView file access pattern, tested in other modules. Android requires WebView.allowFileAccess = true (already enabled). |
| Photo preview memory pressure on low-end devices | MEDIUM | MEDIUM | Compress photos to 1920x1080 before preview, dispose camera controller immediately after capture, use cached thumbnails for gallery display. |
| Permission confusion between barcode and photo | LOW | LOW | Same PermissionHandlerService, same permission (android.permission.CAMERA), same error messages. AC-5.1.16 validates consistent behavior. |

**Overall Risk Level**: 🟢 LOW - Proven plugins (camera, image), standard patterns, clear separation from Phase 5, comprehensive testing

## Timeline Estimate

- PLANNER: 1.5 hours (this document)
- VALIDATOR: 45 minutes (resolve 5 unclear requirements, validate dependencies, check interface contracts)
- BUILDER: 4-5 hours (5 new files ~900 lines, 3 modified Flutter files, React UI updates ~150 lines)
- REVIEWER: 45 minutes (code review, null safety checks, imports validation, bridge registration)
- TESTER: 1.5 hours (19 new acceptance criteria + 4 regression tests)

**Total Phase 5.1 Estimate**: 8.5-10 hours from validation to complete

## Success Metrics

**Functional Completeness**:
- ✅ Users can capture photos using device camera
- ✅ Users can preview and confirm/retake before saving
- ✅ Users can attach up to 5 photos per line item
- ✅ Users can view thumbnails and full-resolution photos
- ✅ Users can delete individual photos
- ✅ Photos persist for 30 days with auto-cleanup
- ✅ Barcode scanning unchanged (AC-5.1.15 regression test)

**Performance Targets**:
- ✅ Photo capture < 3 seconds (AC-5.1.11)
- ✅ Photo file size < 500KB (AC-5.1.12)
- ✅ Thumbnail generation < 200ms (AC-5.1.13)
- ✅ Cleanup process < 2 seconds (AC-5.1.14)
- ✅ APK size increase < 5MB (AC-5.1.19)

**Quality Standards**:
- ✅ All 19 acceptance criteria pass
- ✅ All 4 regression tests pass (Phase 5 functionality preserved)
- ✅ 0 compilation errors or warnings
- ✅ No camera interference between barcode and photo
- ✅ Photo storage isolated from barcode scanning

## Future Enhancements (Out of Scope for Phase 5.1)

### Phase 5.2: Backend Photo Upload
- POST /api/photos multipart upload endpoint
- Photo upload queue with offline support
- Photo sync on transaction submission
- Photo URL storage in transaction records
- Photo retrieval from backend (GET /api/photos/:id)

### Phase 5.3: Photo Editing
- Crop tool with aspect ratio presets
- Rotate 90° increments
- Brightness/contrast adjustment
- Annotate photos (arrows, text, circles, highlights)

### Phase 5.4: Photo Intelligence
- OCR text extraction from photos (read serial numbers, lot codes)
- Barcode detection in photos (scan from gallery)
- Duplicate photo detection (avoid redundant captures)
- Photo quality scoring (blur detection, lighting check)

### Phase 5.5: Photo Gallery
- All photos view across all transactions
- Search photos by date, SKU, transaction ID, caption
- Bulk delete and bulk export
- Photo slideshow for audits

---

**Phase 5.1 Status**: PLANNED - Ready for Validator Review

**Critical Success Factors**:
1. Validator resolves 5 unclear requirements (flashlight, captions, camera facing, quality settings, photo lifecycle)
2. Builder maintains strict separation from Phase 5 barcode scanning code
3. Tester validates all 4 regression tests pass (barcode scanning unaffected)
4. Photo capture time < 3 seconds on target devices
5. APK size increase < 5MB

**Handoff to Validator**: Review this plan, resolve unclear requirements, validate interface contracts, confirm dependencies available.
