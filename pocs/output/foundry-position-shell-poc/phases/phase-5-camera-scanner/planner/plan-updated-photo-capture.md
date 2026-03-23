# Phase 5.1 — Photo Capture Extension (UPDATED PLAN)
PHASE_ID: photo-capture-phase-5.1
PLANNER_DOC_VERSION: 1.0.0
DEPENDS_ON: [phase-5-camera-scanner]
PROVIDES_TO: [none] | [final]

---

## PLAN UPDATE SUMMARY

**Original Phase 5**: Barcode/QR scanning for auto-fill ✅ COMPLETE
**Phase 5.1 Addition**: Photo capture for product documentation ⏳ PLANNED

**User Requirement**: "I should have both features like barcode and photo taken"

This updated plan extends Phase 5 to add photo capture while preserving existing barcode scanning functionality.

---

## What This Phase Builds

Phase 5.1 adds native camera-based photo capture capability to the warehouse management app, complementing the existing barcode scanning feature from Phase 5. Users will now have TWO camera-based features:

1. **Barcode Scanning** (✅ Already Implemented - Phase 5)
   - Scan product barcodes/QR codes
   - Auto-fill form fields (SKU, description, location)
   - Use case: Fast data entry

2. **Photo Capture** (⏳ New - Phase 5.1)
   - Take photos of products, damage, labels, packaging
   - Attach up to 5 photos per line item
   - Display thumbnails in form, view full-res in modal
   - Use case: Documentation and quality records

Implementation includes Flutter photo capture service via camera plugin, photo storage management, thumbnail generation, React photo gallery UI, and photo lifecycle management (capture, display, delete, cleanup).

---

## Architecture Overview

### TWO Bridge Methods (Separate Concerns)

```typescript
// EXISTING - Phase 5 - Barcode Scanning
window.shellBridge.scanBarcode() → {
  success: boolean,
  barcode?: string,
  format?: string,
  error?: string
}

// NEW - Phase 5.1 - Photo Capture
window.shellBridge.capturePhoto(options?: {
  quality?: number,
  maxWidth?: number,
  maxHeight?: number
}) → {
  success: boolean,
  photoUri?: string,
  photoBase64?: string,
  timestamp?: number,
  width?: number,
  height?: number,
  fileSize?: number,
  error?: string
}

// NEW - Phase 5.1 - Photo Deletion
window.shellBridge.deletePhoto({
  photoUri: string
}) → {
  success: boolean,
  error?: string
}
```

### Design Philosophy

**Separation of Concerns**: Barcode scanning and photo capture are implemented as separate bridge methods with separate services, preventing interference and allowing independent testing.

**Reuse Existing Infrastructure**: Photo capture reuses camera permissions (permission_handler_service.dart), bridge patterns (scanner_bridge_extension.dart), and full-screen UI patterns (scanner_screen.dart).

**Local-First Storage**: Photos stored locally in app Documents directory, no backend dependency in Phase 5.1. Backend upload deferred to Phase 5.2 (future enhancement).

**User Control**: Users explicitly capture photos (not automatic), can preview before accepting, can delete individual photos, and can capture multiple photos per item.

---

## Requirements Covered

### EXISTING - Phase 5 (Preserved)
- REQ-F1: Scan product barcodes (UPC, EAN, Code 128) ✅
- REQ-F2: Scan location QR codes ✅
- REQ-F3: Auto-fill form fields with scanned data ✅
- REQ-F4: Lookup product details from backend ✅
- REQ-F5: Manual entry fallback if scan fails ✅
- REQ-F6: Camera permission handling ✅
- REQ-F7: Flashlight toggle for low light ✅
- REQ-F8: Single scan mode (scan once, close camera) ✅

### NEW - Phase 5.1 (Photo Capture)

**Functional Requirements**:
- REQ-F9: Capture photos of products, labels, damage, or packaging using device camera
- REQ-F10: Attach multiple photos to each line item (max 5 photos per item, unlimited items)
- REQ-F11: Display photo thumbnails (200x200) in line item form row
- REQ-F12: View full-resolution photo in modal overlay (click thumbnail to open)
- REQ-F13: Delete individual photos before transaction submission
- REQ-F14: Preview photo after capture with confirm/retake options
- REQ-F15: Store photos locally with 30-day retention policy

**Technical Requirements**:
- REQ-T7: Use Flutter camera plugin (camera: ^0.10.0) for photo capture
- REQ-T8: Save photos to app Documents directory (platform-specific path)
- REQ-T9: Generate thumbnails (200x200 max) for React display (WebP format)
- REQ-T10: Return photo URI (file:// scheme) to React via bridge
- REQ-T11: Auto-cleanup photos older than 30 days on app start
- REQ-T12: Compress photos to max 1920x1080 resolution, 85% JPEG quality
- REQ-T13: Unique filenames using timestamp + random UUID (collision prevention)
- REQ-T14: Reuse existing camera permission service from Phase 5

**Non-Functional Requirements**:
- REQ-NF6: Photo capture time < 3 seconds (button tap to photo saved)
- REQ-NF7: Photo file size < 500KB after compression (network-friendly)
- REQ-NF8: Support up to 250 photos total per transaction (50 items × 5 photos)
- REQ-NF9: Thumbnail generation < 200ms per photo (non-blocking)
- REQ-NF10: Photo cleanup process < 2 seconds on app start
- REQ-NF11: Photo display in React < 500ms (file:// URI loading)
- REQ-NF12: APK size increase < 12MB (camera plugin + image library)

---

## Deliverables

### NEW Flutter Components (5 files)

- [ ] C:\Users\bijay\OneDrive\Desktop\auto_agent3\pocs\output\foundry-position-shell-poc\src\shell\lib\bridge\photo_bridge_extension.dart: Flutter bridge extension for photo methods (capturePhoto, deletePhoto)
- [ ] C:\Users\bijay\OneDrive\Desktop\auto_agent3\pocs\output\foundry-position-shell-poc\src\shell\lib\photo\photo_capture_service.dart: Photo capture service using camera plugin
- [ ] C:\Users\bijay\OneDrive\Desktop\auto_agent3\pocs\output\foundry-position-shell-poc\src\shell\lib\photo\photo_capture_screen.dart: Full-screen camera UI for photo taking with preview
- [ ] C:\Users\bijay\OneDrive\Desktop\auto_agent3\pocs\output\foundry-position-shell-poc\src\shell\lib\photo\photo_storage_service.dart: Photo file management, cleanup, and retrieval
- [ ] C:\Users\bijay\OneDrive\Desktop\auto_agent3\pocs\output\foundry-position-shell-poc\src\shell\lib\photo\thumbnail_generator.dart: Thumbnail generation (200x200 WebP)

### MODIFIED Flutter Components (3 files)

- [ ] C:\Users\bijay\OneDrive\Desktop\auto_agent3\pocs\output\foundry-position-shell-poc\src\shell\lib\main.dart: Register photo bridge extension
- [ ] C:\Users\bijay\OneDrive\Desktop\auto_agent3\pocs\output\foundry-position-shell-poc\src\shell\lib\bridge\shell_bridge.dart: Add capturePhoto and deletePhoto method handlers
- [ ] C:\Users\bijay\OneDrive\Desktop\auto_agent3\pocs\output\foundry-position-shell-poc\src\shell\pubspec.yaml: Add camera: ^0.10.0, image: ^4.0.0, uuid: ^4.0.0 dependencies

### MODIFIED React UI (1 file)

- [ ] C:\Users\bijay\OneDrive\Desktop\auto_agent3\pocs\output\foundry-position-shell-poc\src\shell\assets\modules\sample-warehouse\index.html: Add photo capture button, thumbnail display, photo modal, delete functionality

### UNCHANGED Files (Preserve Existing Functionality)

- ✅ scanner_bridge_extension.dart - Barcode scanning bridge (no changes)
- ✅ barcode_scanner_service.dart - Barcode scanning service (no changes)
- ✅ scanner_screen.dart - Barcode scanner UI (no changes)
- ✅ permission_handler_service.dart - Camera permissions (reused, no changes)
- ✅ server.js - Backend product lookup (no changes)
- ✅ seed.js - Product database (no changes)

---

## Inputs From Previous Phase

### Phase 5 Outputs (Reused in Phase 5.1)

- **Camera Permission Service**: permission_handler_service.dart provides camera permission handling (checkCameraPermission, requestCameraPermission) - will be reused by photo capture
- **Bridge Pattern**: scanner_bridge_extension.dart establishes pattern for bridge extensions - photo_bridge_extension.dart will follow same pattern
- **Full-Screen Camera UI Pattern**: scanner_screen.dart provides full-screen camera layout pattern - photo_capture_screen.dart will follow similar structure
- **ShellBridge Infrastructure**: shell_bridge.dart provides method routing - will add photo method handlers alongside existing scanner methods
- **React Camera Integration**: index.html demonstrates React-Flutter camera integration - photo UI will use same patterns

---

## Outputs To Next Phase

### Phase 5.1 Outputs

- **Photo Bridge Extension**: photo_bridge_extension.dart provides capturePhoto() and deletePhoto() methods for React modules
- **Photo Storage Infrastructure**: photo_storage_service.dart manages photo lifecycle (save, retrieve, cleanup, thumbnail generation)
- **Photo Data Model**: Line items can have `photos: [{uri, timestamp, caption}]` array for attaching documentation
- **Photo UI Components**: React photo gallery patterns (thumbnails, modal, delete) for future modules

### Future Phases (Out of Scope)

- **Phase 5.2 (Future)**: Backend photo upload (POST /api/photos, photo sync queue, offline photo upload)
- **Phase 5.3 (Future)**: Photo editing (crop, rotate, annotate, filters)
- **Phase 5.4 (Future)**: Photo search (OCR text extraction, barcode detection in photos)

---

## Architecture Details

### Photo Storage Structure

```
Android: /data/data/com.foundry.shell/app_flutter/photos/
iOS: {Application Documents Directory}/photos/

photos/
├── originals/
│   ├── 2026-03-23_123045_a1b2c3d4.jpg  (full-res photo, max 1920x1080, <500KB)
│   ├── 2026-03-23_123512_e5f6g7h8.jpg
│   └── 2026-03-23_144235_i9j0k1l2.jpg
├── thumbnails/
│   ├── 2026-03-23_123045_a1b2c3d4_thumb.webp  (200x200 max, <50KB)
│   ├── 2026-03-23_123512_e5f6g7h8_thumb.webp
│   └── 2026-03-23_144235_i9j0k1l2_thumb.webp
└── .cleanup_timestamp  (last cleanup timestamp for 30-day retention)
```

**Filename Format**: `YYYY-MM-DD_HHMMSS_{uuid}.{ext}`
- Timestamp: Sortable, human-readable
- UUID: Prevents collisions (random 8-char hex)
- Extension: `.jpg` for originals, `.webp` for thumbnails

**Retention Policy**: Photos older than 30 days deleted on app start

### Data Flow Diagrams

#### Photo Capture Flow

```
User taps 📸 button
  ↓
React calls window.shellBridge.capturePhoto({quality: 85})
  ↓
photo_bridge_extension.dart receives call
  ↓
Check camera permission (reuse permission_handler_service.dart)
  ↓ (if granted)
Launch photo_capture_screen.dart (full-screen camera)
  ↓
User takes photo → Preview shown → User confirms
  ↓
photo_capture_service.dart captures image
  ↓
photo_storage_service.dart:
  - Saves original to photos/originals/ (compressed 1920x1080, 85% quality)
  - Generates thumbnail to photos/thumbnails/ (200x200 WebP)
  ↓
Return {success: true, photoUri: "file://...", timestamp: ...}
  ↓
React receives result, updates line item state:
  lineItems[id].photos.push({uri: photoUri, timestamp: ...})
  ↓
React displays thumbnail in line item row
  ↓
User clicks thumbnail → Photo modal opens with full-res image
```

#### Photo Deletion Flow

```
User clicks 🗑️ on photo thumbnail
  ↓
React calls window.shellBridge.deletePhoto({photoUri: "file://..."})
  ↓
photo_bridge_extension.dart receives call
  ↓
photo_storage_service.dart:
  - Deletes original from photos/originals/
  - Deletes thumbnail from photos/thumbnails/
  ↓
Return {success: true}
  ↓
React removes photo from line item state:
  lineItems[id].photos = photos.filter(p => p.uri !== photoUri)
  ↓
Thumbnail disappears from UI
```

### React UI Layout

```
Line Item Row:
┌─────────────────────────────────────────────────────────────────┐
│ SKU: [WGT-001    ] 📷 📸                                        │
│ Description: [Widget Alpha                                 ]    │
│ Quantity: [10] Location: [A-01-03] 📱                           │
│                                                                  │
│ Photos: [📷 thumb1] [📷 thumb2] [📷 thumb3] (+ Add Photo)      │
│         ↑ click to view full-res in modal                       │
└─────────────────────────────────────────────────────────────────┘

Legend:
📷 = Barcode scan button (existing)
📸 = Photo capture button (new)
📱 = QR scan button (existing)
[📷 thumb1] = Photo thumbnail with delete icon overlay
```

### Photo Modal

```
┌─────────────────────────────────────────────────────────────────┐
│ [← Back]                    Photo 2 of 3           [🗑️ Delete]  │
│                                                                  │
│                                                                  │
│                  ┌────────────────────┐                         │
│                  │                    │                         │
│                  │   Full-Res Photo   │                         │
│                  │   (click to zoom)  │                         │
│                  │                    │                         │
│                  └────────────────────┘                         │
│                                                                  │
│             [← Prev]              [Next →]                      │
│                                                                  │
│ Taken: 2026-03-23 12:30:45                                      │
│ Caption: [Damaged corner, see right edge              ]         │
└─────────────────────────────────────────────────────────────────┘
```

---

## Acceptance Criteria

### EXISTING - Phase 5 (Regression Tests)

- [ ] AC-5.1: Camera opens in < 1 second when scan button pressed ✅ MUST STILL PASS
- [ ] AC-5.2: Barcode detection < 2 seconds ✅ MUST STILL PASS
- [ ] AC-5.3: Scanned barcode triggers auto-fill ✅ MUST STILL PASS
- [ ] AC-5.8: scanBarcode returns consistent response format ✅ MUST STILL PASS
- [ ] AC-5.9: Backend product lookup < 500ms ✅ MUST STILL PASS

### NEW - Phase 5.1 (Photo Capture)

- [ ] AC-5.1.1
      criterion: Photo button opens camera in less than 2 seconds when pressed
      test_command: adb logcat -s "PhotoCapture:*" | grep "Camera opened in"
      pass_condition: Log shows "Camera opened in XXXms" where XXX < 2000
      blocking: true

- [ ] AC-5.1.2
      criterion: User can take photo and see preview immediately
      test_command: Manual test - tap photo button, take photo, verify preview shows
      pass_condition: Preview displays within 500ms of shutter button press
      blocking: true

- [ ] AC-5.1.3
      criterion: User can confirm or retake photo from preview screen
      test_command: Manual test - take photo, tap Retake button, verify camera reopens
      pass_condition: Retake returns to camera view, Confirm saves photo
      blocking: true

- [ ] AC-5.1.4
      criterion: Confirmed photo attaches to correct line item and returns photoUri
      test_command: Manual test - capture photo for line item 1, verify lineItems[0].photos contains new entry
      pass_condition: React state updated with {uri: "file://...", timestamp: ...}
      blocking: true

- [ ] AC-5.1.5
      criterion: Photo thumbnail displays in line item row immediately after capture
      test_command: Manual test - capture photo, verify thumbnail appears in UI
      pass_condition: Thumbnail image visible, clickable, < 1 second to render
      blocking: true

- [ ] AC-5.1.6
      criterion: User can capture up to 5 photos per line item
      test_command: Manual test - capture 5 photos for one line item, verify 6th capture shows error
      pass_condition: Photos 1-5 succeed, 6th shows "Maximum 5 photos per item"
      blocking: true

- [ ] AC-5.1.7
      criterion: User can delete individual photos via delete button
      test_command: Manual test - capture 3 photos, delete middle photo, verify correct photo removed
      pass_condition: Correct photo disappears from UI, file deleted from storage
      blocking: true

- [ ] AC-5.1.8
      criterion: User can click thumbnail to view full-resolution photo in modal
      test_command: Manual test - click thumbnail, verify modal opens with full-res image
      pass_condition: Modal displays full photo, close button works, swipe navigation works (if multiple photos)
      blocking: true

- [ ] AC-5.1.9
      criterion: Photos persist in React state until transaction submission or manual deletion
      test_command: Manual test - capture photos, switch tabs, return to Create tab, verify photos still visible
      pass_condition: Photos remain attached to line items across tab switches
      blocking: true

- [ ] AC-5.1.10
      criterion: Photos older than 30 days are auto-deleted on app start
      test_command: Modify .cleanup_timestamp to 31 days ago, restart app, check photos directory
      pass_condition: Old photos deleted, recent photos preserved, cleanup log shows "Deleted X old photos"
      blocking: true

- [ ] AC-5.1.11
      criterion: Photo capture completes in < 3 seconds from button tap to saved file
      test_command: adb logcat -s "PhotoCapture:*" | grep "Photo saved in"
      pass_condition: Log shows "Photo saved in XXXms" where XXX < 3000
      blocking: true

- [ ] AC-5.1.12
      criterion: Photo file size < 500KB after compression
      test_command: adb shell ls -lh /data/data/com.foundry.shell/app_flutter/photos/originals/
      pass_condition: All photo files < 500KB (check multiple photos in various lighting)
      blocking: true

- [ ] AC-5.1.13
      criterion: Thumbnail generation < 200ms per photo
      test_command: adb logcat -s "Thumbnail:*" | grep "Thumbnail generated in"
      pass_condition: Log shows "Thumbnail generated in XXXms" where XXX < 200
      blocking: true

- [ ] AC-5.1.14
      criterion: Photo cleanup process < 2 seconds on app start
      test_command: adb logcat -s "PhotoStorage:*" | grep "Cleanup completed in"
      pass_condition: Log shows "Cleanup completed in XXXms" where XXX < 2000 (even with 100+ photos)
      blocking: true

- [ ] AC-5.1.15
      criterion: Barcode scanning still works after photo capture feature added (regression)
      test_command: Manual test - tap barcode scan button, scan barcode, verify form auto-fills
      pass_condition: Barcode scanning works identically to Phase 5 (AC-5.3 passes)
      blocking: true

- [ ] AC-5.1.16
      criterion: Camera permissions work for both scanBarcode and capturePhoto
      test_command: Manual test - revoke camera permission, tap scan button (denied), grant permission, tap photo button (works)
      pass_condition: Both features respect camera permission state, both show same permission error
      blocking: true

- [ ] AC-5.1.17
      criterion: No interference between scanBarcode and capturePhoto operations
      test_command: Manual test - rapidly alternate between scan and photo buttons
      pass_condition: Each operation completes correctly, no camera lockup or crashes
      blocking: true

- [ ] AC-5.1.18
      criterion: Bridge method capturePhoto returns consistent response format
      test_command: adb logcat -s "ShellBridge:*" | grep "capturePhoto result:"
      pass_condition: Result JSON contains {success: boolean, photoUri?: string, timestamp?: number, error?: string}
      blocking: true

- [ ] AC-5.1.19
      criterion: APK size increase < 12MB after adding camera and image plugins
      test_command: ls -lh build/app/outputs/flutter-apk/app-release.apk (before and after Phase 5.1)
      pass_condition: APK size delta < 12MB (camera ~8MB, image ~2MB, code ~500KB)
      blocking: false

---

## Manual Test Steps

### Phase 5 Regression Tests (Ensure Barcode Scanning Still Works)

1. Launch app and login → Expected: Warehouse module loads
2. Navigate to Create Transaction tab → Expected: Transaction form displays
3. Add line item → Expected: Empty line item row with scan buttons
4. Tap barcode scan button (📷) → Expected: Camera opens, barcode detection works
5. Scan barcode → Expected: Form auto-fills (AC-5.3 regression)

### Phase 5.1 Photo Capture Tests (New Functionality)

6. Tap photo capture button (📸) next to SKU field → Expected: Camera opens in < 2 seconds
7. Take photo using shutter button → Expected: Preview shows immediately
8. Tap Retake button → Expected: Returns to camera view
9. Take another photo, tap Confirm → Expected: Camera closes, returns to form
10. Verify thumbnail appears in line item → Expected: 200x200 thumbnail visible in < 1 second
11. Click thumbnail → Expected: Modal opens with full-resolution photo
12. Click close button in modal → Expected: Modal closes, form visible
13. Tap photo button 4 more times, capture 4 photos → Expected: 5 thumbnails total shown
14. Tap photo button again (6th photo) → Expected: Error message "Maximum 5 photos per item"
15. Click delete icon on 3rd photo → Expected: Photo removed from UI and storage
16. Switch to History tab and back → Expected: Photos still visible in Create tab
17. Add second line item, capture 2 photos → Expected: Photos attached to correct line item
18. Submit transaction → Expected: Transaction saves successfully (photos NOT uploaded to backend in Phase 5.1)
19. Restart app → Expected: Photos from active transaction gone (transaction submitted)

### Permission Tests

20. Revoke camera permission in Android settings
21. Tap barcode scan button → Expected: Permission error message
22. Tap photo capture button → Expected: Same permission error message
23. Grant camera permission → Expected: Both features work

### Performance Tests

24. Capture photo in bright light → Expected: File size < 500KB, thumbnail generated < 200ms
25. Capture photo in low light → Expected: File size < 500KB (verify compression)
26. Capture 10 photos rapidly → Expected: All succeed, no crashes, all < 3 seconds each

### Cleanup Test

27. Manually set .cleanup_timestamp to 31 days ago (or modify date check in code for testing)
28. Restart app → Expected: Old photos deleted, cleanup log shows count
29. Verify recent photos preserved → Expected: Only old photos deleted

---

## Phase Achievement

Warehouse clerks can scan product barcodes for auto-fill (Phase 5) AND capture photos to document product condition, damage, or labels (Phase 5.1). Both features use native device camera with permission handling, providing comprehensive warehouse documentation capabilities.

---

## Planner Notes

### Design Decisions Made

✅ **DECIDED**: Photo storage location = Local app Documents directory (not backend upload in Phase 5.1)
- Rationale: Simpler implementation, faster capture, no network dependency
- Future: Backend upload in Phase 5.2

✅ **DECIDED**: Photo return format = Both URI and base64
- Rationale: URI for efficient local display, base64 for future backend upload
- Implementation: Return photoUri always, photoBase64 only if image < 800px

✅ **DECIDED**: Photo attachment = Line item level (not transaction level)
- Rationale: Photos document specific products/SKUs, not entire transaction
- Data model: lineItems[i].photos = [{uri, timestamp, caption}]

✅ **DECIDED**: Max photos = 5 per line item
- Rationale: Covers documentation needs (front, back, label, damage, packaging)
- Storage: 50 items × 5 photos × 500KB = 125MB max per transaction (acceptable)

✅ **DECIDED**: Photo retention = 30 days
- Rationale: Sufficient for transaction review/disputes, prevents unbounded storage growth
- Implementation: Auto-cleanup on app start using file modification timestamps

✅ **DECIDED**: Photo preview = YES, Photo crop = NO (Phase 5.1)
- Rationale: Preview essential for quality check, crop adds significant UI complexity
- Future: Crop in Phase 5.3 if needed

✅ **DECIDED**: Photo gallery view = NO (Phase 5.1)
- Rationale: Inline thumbnails sufficient for MVP, gallery adds navigation complexity
- Future: Gallery in Phase 5.3 if needed

✅ **DECIDED**: Plugin choice = camera ^0.10.0 (not mobile_scanner)
- Rationale: mobile_scanner optimized for barcode detection, camera plugin better for photo capture quality
- Trade-off: Two camera plugins (~8MB each), but best tool for each job

### Unclear Requirements (Need Validation)

⚠ **UNCLEAR**: Should photos be submitted with transaction to backend in Phase 5.1?
- Current assumption: Photos stay local only, backend upload deferred to Phase 5.2
- Validator should confirm if backend POST /api/transactions needs photo upload capability in Phase 5.1
- Impact: If YES, need to add multipart/form-data upload logic, photo serialization

⚠ **UNCLEAR**: Should user be able to add captions to photos?
- Current assumption: Optional caption field in photo data model {uri, timestamp, caption?}
- Validator should confirm if caption UI needed (text input under thumbnail)
- Impact: Minor - adds one text input to photo modal

⚠ **UNCLEAR**: Should photos be attached to specific SKUs or generic line items?
- Current assumption: Photos attached to line items (SKU + quantity + location + photos)
- Validator should confirm if photos should be SKU-level (shared across all instances of SKU-123)
- Impact: Major architectural change if SKU-level (need photo database, not per-transaction)

⚠ **UNCLEAR**: Flashlight toggle for photo capture?
- Current assumption: NO flashlight toggle (camera auto-adjusts exposure)
- Validator should confirm if manual flashlight toggle needed like barcode scanner
- Impact: Minor - reuse flashlight toggle from scanner_screen.dart

⚠ **UNCLEAR**: Photo capture from both cameras (front/back)?
- Current assumption: Back camera only (like barcode scanner)
- Validator should confirm if front camera needed (selfie use case unclear for warehouse)
- Impact: Minor - add camera facing toggle button

---

## Dependencies

### Flutter Dependencies (Added to pubspec.yaml)

```yaml
dependencies:
  # Existing Phase 5
  mobile_scanner: ^5.0.0          # Barcode scanning
  permission_handler: ^11.0.0     # Camera permissions (reused)

  # NEW Phase 5.1
  camera: ^0.10.0                 # Photo capture (~8MB APK)
  image: ^4.0.0                   # Image processing, thumbnails (~2MB APK)
  uuid: ^4.0.0                    # Unique filenames (~50KB APK)
  path_provider: ^2.0.0           # App documents directory (~100KB APK)
```

**Total APK Size Impact**: ~10.15MB (acceptable per AC-5.1.19 target of <12MB)

### Existing Phase 5 Components (Reused)

- permission_handler_service.dart - Camera permissions (no changes needed)
- Bridge registration pattern from scanner_bridge_extension.dart
- Full-screen camera UI pattern from scanner_screen.dart
- ShellBridge method routing from shell_bridge.dart

---

## Risk Assessment

| Risk | Severity | Likelihood | Mitigation |
|------|----------|------------|------------|
| Camera plugin conflicts with mobile_scanner | MEDIUM | LOW | Separate plugins, separate services, separate bridge methods. Tested in isolation first. |
| Photo storage fills device | MEDIUM | MEDIUM | 30-day retention, auto-cleanup on start, 500KB max per photo, 5 photos per item limit |
| React file:// URI not loading | LOW | LOW | Standard WebView file access, tested in POC |
| Thumbnail generation slow | LOW | MEDIUM | Use image package (fast native code), 200ms target, non-blocking async |
| Permission denial after Phase 5 | LOW | LOW | Reuse same permission_handler_service.dart, both features use same permission |
| Photo modal UI complex | MEDIUM | MEDIUM | Start with simple modal (no crop/zoom), enhance in Phase 5.3 if needed |

**Overall Risk Level**: 🟡 MEDIUM-LOW - Well-understood technologies, clear architecture, proven patterns

---

## Timeline Estimate

- PLANNER: 1 hour (this document)
- VALIDATOR: 30 minutes (review requirements, check dependencies)
- BUILDER: 3-4 hours (5 new files + 4 modified files + React UI)
- REVIEWER: 30 minutes (code review, imports check)
- TESTER: 1 hour (17 new ACs + 5 regression tests)

**Total**: 6-7 hours for Phase 5.1 completion

---

## Success Metrics

**Functional Completeness**:
- ✅ Users can capture photos for line items
- ✅ Users can view, delete, and manage photos
- ✅ Photos persist until transaction submission
- ✅ Barcode scanning unaffected (regression)

**Performance**:
- ✅ Photo capture < 3 seconds
- ✅ Photo file size < 500KB
- ✅ Thumbnail generation < 200ms
- ✅ Photo cleanup < 2 seconds

**Quality**:
- ✅ All ACs pass (17 new + 5 regression)
- ✅ 0 compilation errors
- ✅ APK size increase < 12MB
- ✅ No camera conflicts between barcode and photo

---

## Future Enhancements (Out of Scope for Phase 5.1)

### Phase 5.2: Backend Photo Sync
- POST /api/photos endpoint (multipart upload)
- Photo upload queue (offline support)
- Photo URL storage in transactions
- Photo retrieval from backend

### Phase 5.3: Photo Editing
- Crop tool with aspect ratio presets
- Rotate 90° increments
- Annotate (arrows, text, circles)
- Filters (grayscale, contrast, brightness)

### Phase 5.4: Photo Intelligence
- OCR text extraction from photos
- Barcode detection in photos (scan from gallery)
- Duplicate photo detection
- Photo quality scoring

### Phase 5.5: Photo Gallery
- All photos view across transactions
- Search photos by date, SKU, transaction
- Bulk delete, bulk export
- Photo slideshow

---

**Phase 5.1 Status**: ⏳ PLANNED - Ready for Validation
**Dependencies**: ✅ Phase 5 Complete
**Estimated Completion**: 6-7 hours after validation approval
