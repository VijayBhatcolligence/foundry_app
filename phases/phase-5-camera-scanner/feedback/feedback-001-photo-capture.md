# FEEDBACK REPORT — FB-001

FEEDBACK_ID: feedback-001-photo-capture
TIMESTAMP: 2026-03-23T12:30:00Z
PHASE_AFFECTED: phase-5-camera-scanner
CYCLE: post-delivery-5
STATUS: CLASSIFIED

---

## Human Input (Verbatim)

### What I Did
"I should have both features like barcode and photo taken - that's what my requirement is. Update plan and tell me how it is designed."

### What I Expected
A warehouse application that provides BOTH barcode scanning (already implemented) AND photo capture capabilities for documenting products, damage, labels, or conditions during warehouse operations.

### What Happened Instead
Phase 5 currently only implements barcode/QR code scanning for auto-filling form fields. There is no photo capture functionality to take and store pictures of products or warehouse items.

### Error Message or Screenshot
None provided - This is a feature gap, not a technical error.

---

## FEEDBACK Classification

### Root Cause Type
SPEC_GAP

### Confidence Level
HIGH

### Reasoning
This is a clear specification gap rather than a bug. The original Phase 5 plan (plan.md) explicitly focused on barcode/QR scanning for data entry auto-fill only. Photo capture was never part of the validated requirements (REQ-F1 through REQ-F8, REQ-T1 through REQ-T6). The implementation correctly delivers what was specified, but the user's actual requirements include an additional camera use case: photo capture for documentation. This represents new functionality that must be designed and added.

### Evidence from Build Artifacts
- **validated.md said**: "REQ-F1: Scan product barcodes (UPC, EAN, Code 128)", "REQ-F2: Scan location QR codes", "REQ-F3: Auto-fill form fields with scanned data" - No mention of photo capture
- **built.md claimed**: "5 new Flutter files (762 lines)" including scanner_bridge_extension.dart, barcode_scanner_service.dart, scanner_screen.dart - All focused on barcode scanning only
- **test-report.md showed**: All 11 acceptance criteria (AC-5.1 through AC-5.11) test barcode scanning, permission handling, and auto-fill - Zero photo capture tests
- **Gap**: User needs BOTH barcode scanning (✅ implemented) AND photo capture (❌ not implemented) to document product condition, damage, labels during receiving/inventory operations

---

## Routing Decision

### Route To
planner

### Action Type
re-plan

### Briefing for Agent

```
You are PLANNER.
agent_doc_version: 6.0.0
Phase: 5.1 of 8 — Photo Capture Extension
Cycle: post-delivery-5
Run type: feedback-driven-enhancement
Source: FEEDBACK_REPORT.md FB-001

Context:
  Phase 5 (Camera/Scanner Integration) was successfully completed with barcode scanning capability.
  React can call window.shellBridge.scanBarcode() to scan barcodes for auto-fill.
  User NOW requests adding photo capture alongside barcode scanning (both features needed).

Problem:
  Current implementation provides barcode scanning only. User needs to also capture photos
  to document product condition, damage, labels, or warehouse items during transactions.
  This requires a second camera use case: taking photos instead of scanning codes.

Job:
  Create Phase 5.1 plan for adding photo capture capability while preserving existing
  barcode scanning functionality. Design TWO separate bridge methods:

  1. scanBarcode() - Existing, keep as-is
  2. capturePhoto() - NEW, opens camera for photo taking

  Design decisions needed:
  - Photo return format: base64 string vs file path URI
  - Photo storage: temporary vs permanent, local vs backend upload
  - Photo attachment: to line items, transactions, or standalone gallery
  - Photo display: thumbnail preview, full view, gallery
  - Photo management: delete, retake, multiple photos per item

  Reference existing scanner architecture:
  - scanner_bridge_extension.dart (bridge pattern)
  - barcode_scanner_service.dart (camera service pattern)
  - scanner_screen.dart (full-screen camera UI pattern)
  - permission_handler_service.dart (already has camera permissions)

Constraints:
  - DO NOT modify: Existing barcode scanning functionality (scanBarcode method)
  - DO NOT modify: Existing scanner_bridge_extension.dart scanBarcode() implementation
  - DO reuse: Camera permissions already implemented (permission_handler_service.dart)
  - DO reuse: Flutter camera access patterns from scanner_screen.dart
  - DO follow: Bridge extension pattern established in Phase 5
  - DO verify: Photos can be attached to line items and displayed in React UI
  - DO test: Photo capture, storage, retrieval, display, and cleanup

See: FEEDBACK_REPORT.md FB-001 for complete context.
```

### Do Not Touch
- C:\Users\bijay\OneDrive\Desktop\auto_agent3\pocs\output\foundry-position-shell-poc\src\shell\lib\bridge\scanner_bridge_extension.dart - Existing barcode scanning bridge (working)
- C:\Users\bijay\OneDrive\Desktop\auto_agent3\pocs\output\foundry-position-shell-poc\src\shell\lib\scanner\barcode_scanner_service.dart - Barcode scanning service (working)
- C:\Users\bijay\OneDrive\Desktop\auto_agent3\pocs\output\foundry-position-shell-poc\src\shell\lib\scanner\permission_handler_service.dart - Camera permissions (reuse this)
- C:\Users\bijay\OneDrive\Desktop\auto_agent3\pocs\output\foundry-position-shell-poc\src\shell\assets\modules\sample-warehouse\index.html - React UI barcode buttons (preserve existing)
- C:\Users\bijay\OneDrive\Desktop\auto_agent3\pocs\output\foundry-position-shell-poc\src\backend\server.js - Product lookup endpoint (working)

### Regression Tests Required
- [ ] AC-5.1: Camera opens < 1 second when scan button is pressed - Must still pass
- [ ] AC-5.2: Barcode detection completes in < 2 seconds - Must still pass
- [ ] AC-5.3: Scanned barcode triggers auto-fill - Must still pass
- [ ] AC-5.8: Bridge method scanBarcode returns consistent response format - Must still pass

---

## Gap Description

The current Phase 5 implementation provides barcode scanning for data entry (scanBarcode method) but does not provide photo capture for documentation (no capturePhoto method). Warehouse operations require BOTH capabilities:

**Use Case 1: Barcode Scanning** (✅ Implemented)
- Purpose: Auto-fill product SKU, name, location from barcode/QR codes
- User Flow: Tap scan icon → Camera opens → Point at barcode → Form auto-fills
- Current Implementation: scanBarcode() bridge method, barcode_scanner_service.dart

**Use Case 2: Photo Capture** (❌ Missing)
- Purpose: Document product condition, damage, labels, packaging during receiving
- User Flow: Tap photo icon → Camera opens → Take picture → Photo attaches to line item → Thumbnail shows in form
- Missing Implementation: No capturePhoto() bridge method, no photo service, no photo storage, no React photo UI

### Why This is a Spec Gap (Not a Bug)

Phase 5 requirements (REQ-F1 through REQ-F8) explicitly covered barcode scanning only. Photo capture was never specified or discussed during planning/validation. User's actual business need includes both camera use cases but only one was captured in original requirements. This is SYSTEMIC gap in requirements gathering, not a code defect.

---

## Proposed Enhancement: Phase 5.1 — Photo Capture Extension

### Architecture Design

#### 1. TWO Bridge Methods (Separate Concerns)

```typescript
// EXISTING - Keep as-is
window.shellBridge.scanBarcode() → Promise<{
  success: boolean,
  barcode?: string,
  format?: string,
  error?: string
}>

// NEW - Photo capture
window.shellBridge.capturePhoto(options?: {
  quality?: number,        // 0-100, default 85
  maxWidth?: number,       // default 1920
  maxHeight?: number,      // default 1080
  saveToGallery?: boolean  // default false
}) → Promise<{
  success: boolean,
  photoUri?: string,       // file:// path to saved image
  photoBase64?: string,    // base64 string (if maxWidth/Height < 800)
  timestamp?: number,      // capture timestamp
  error?: string
}>
```

**Design Decision**: Return both `photoUri` (efficient for local storage/display) AND `photoBase64` (for small images that need backend upload). React can choose based on use case.

#### 2. Flutter Components (New Files)

**A. Photo Bridge Extension**
- File: `photo_bridge_extension.dart` (new)
- Registers `capturePhoto` method with ShellBridge
- Handles photo options (quality, dimensions)
- Returns photo URI + optional base64

**B. Photo Capture Service**
- File: `photo_capture_service.dart` (new)
- Uses `camera` plugin (not mobile_scanner)
- Takes single photo (not video)
- Saves to app's Documents directory
- Generates unique filenames (timestamp-based)

**C. Photo Capture Screen**
- File: `photo_capture_screen.dart` (new)
- Full-screen camera preview
- Capture button, cancel button
- Photo preview after capture (confirm/retake)
- Flashlight toggle (reuse from scanner_screen.dart pattern)

**D. Photo Storage Service**
- File: `photo_storage_service.dart` (new)
- Manages photo files in app directory
- Cleanup old photos (retention policy: 30 days)
- Generates thumbnails for React display
- Provides photo retrieval by URI

#### 3. Storage Architecture

**Local Storage (Primary)**
```
Android: /data/data/com.foundry.shell/app_flutter/photos/
iOS: {app_documents_directory}/photos/

Structure:
  photos/
    ├── 2026-03-23_123045_abc123.jpg  (full-res photo)
    ├── 2026-03-23_123045_abc123_thumb.jpg  (thumbnail 200x200)
    └── 2026-03-23_143512_def456.jpg
```

**Retention Policy**: Delete photos older than 30 days (configurable)

**Backend Upload (Optional - Phase 5.2)**
- NOT implemented in Phase 5.1
- Photos stay local only
- Future enhancement: Upload to backend when line item submitted

#### 4. React UI Integration

**A. Photo Capture Button** (Add to line item row)
```html
<div className="input-with-scan">
  <input type="text" value={item.sku} ... />
  <button onClick={() => handleBarcodeScan(item.id)}>📷</button>  <!-- Existing -->
  <button onClick={() => handlePhotoCapture(item.id)}>📸</button>  <!-- NEW -->
</div>
```

**B. Photo Thumbnail Display** (Show captured photos)
```html
{item.photos && item.photos.length > 0 && (
  <div className="photo-thumbnails">
    {item.photos.map(photo => (
      <img
        key={photo.uri}
        src={photo.uri}
        onClick={() => showPhotoModal(photo)}
        className="photo-thumb"
      />
    ))}
  </div>
)}
```

**C. Photo Modal** (Full-screen photo view)
- Click thumbnail → Opens modal with full photo
- Delete button, close button
- Swipe between multiple photos

#### 5. Data Model Updates

**Line Item Schema** (React state)
```typescript
{
  id: number,
  sku: string,
  description: string,
  quantity: number,
  location: string,
  photos: [  // NEW
    {
      uri: string,        // file:// path
      timestamp: number,
      caption?: string    // optional user caption
    }
  ]
}
```

**Backend Transaction Model** (Future - Phase 5.2)
```json
{
  "transactionId": "TXN-123",
  "lineItems": [
    {
      "sku": "WGT-001",
      "photos": [
        {
          "url": "https://backend/photos/abc123.jpg",
          "uploadedAt": 1234567890
        }
      ]
    }
  ]
}
```

### Updated Requirements

**NEW Functional Requirements**:
- REQ-F9: Capture photos of products, labels, damage, or packaging
- REQ-F10: Attach multiple photos to each line item (max 5 per item)
- REQ-F11: Display photo thumbnails in line item form
- REQ-F12: View full-resolution photo in modal
- REQ-F13: Delete photos before transaction submission
- REQ-F14: Retake photo if unsatisfactory
- REQ-F15: Store photos locally for 30 days

**NEW Technical Requirements**:
- REQ-T7: Use Flutter camera plugin for photo capture
- REQ-T8: Save photos to app Documents directory
- REQ-T9: Generate thumbnails (200x200) for React display
- REQ-T10: Return photo URI to React via bridge
- REQ-T11: Cleanup photos older than 30 days on app start
- REQ-T12: Compress photos to max 1920x1080, 85% quality

**NEW Non-Functional Requirements**:
- REQ-NF6: Photo capture time < 3 seconds (camera open to photo saved)
- REQ-NF7: Photo file size < 500KB (after compression)
- REQ-NF8: Support up to 50 photos per transaction (10 items × 5 photos)
- REQ-NF9: Thumbnail generation < 200ms
- REQ-NF10: Photo cleanup process < 2 seconds on app start

### Updated Deliverables

**Flutter Components (5 new files)**:
- [ ] photo_bridge_extension.dart - Bridge layer for capturePhoto method
- [ ] photo_capture_service.dart - Camera plugin integration for photos
- [ ] photo_capture_screen.dart - Full-screen camera UI for photo taking
- [ ] photo_storage_service.dart - Photo file management and cleanup
- [ ] thumbnail_generator.dart - Generate 200x200 thumbnails

**Flutter Modifications (3 files)**:
- [ ] main.dart - Register photo bridge extension
- [ ] shell_bridge.dart - Add capturePhoto method handler
- [ ] pubspec.yaml - Add camera: ^0.10.0, image: ^4.0.0 dependencies

**React UI Updates (1 file)**:
- [ ] index.html - Add photo capture buttons, thumbnail display, photo modal, photo deletion

**Backend (Optional - Phase 5.2, not Phase 5.1)**:
- [ ] POST /api/photos - Upload photo endpoint (future)
- [ ] GET /api/photos/:id - Retrieve photo endpoint (future)

### Updated Acceptance Criteria

**Photo Capture Flow**:
- [ ] AC-5.1.1: Photo button opens camera in < 2 seconds
- [ ] AC-5.1.2: User can take photo and see preview
- [ ] AC-5.1.3: User can confirm or retake photo
- [ ] AC-5.1.4: Confirmed photo attaches to line item
- [ ] AC-5.1.5: Photo thumbnail displays in line item row

**Photo Management**:
- [ ] AC-5.1.6: User can capture up to 5 photos per line item
- [ ] AC-5.1.7: User can delete individual photos
- [ ] AC-5.1.8: User can view full-resolution photo in modal
- [ ] AC-5.1.9: Photos persist until transaction submission
- [ ] AC-5.1.10: Photos older than 30 days are auto-deleted

**Performance**:
- [ ] AC-5.1.11: Photo capture completes in < 3 seconds
- [ ] AC-5.1.12: Photo file size < 500KB after compression
- [ ] AC-5.1.13: Thumbnail generation < 200ms
- [ ] AC-5.1.14: Photo cleanup < 2 seconds on app start

**Regression**:
- [ ] AC-5.1.15: Barcode scanning still works (AC-5.3 regression)
- [ ] AC-5.1.16: Camera permissions work for both scan and photo
- [ ] AC-5.1.17: No interference between scanBarcode and capturePhoto

### Updated Interface Contracts

```dart
// EXISTING - No changes
Future<Map<String, dynamic>> scanBarcode() async {
  return {
    'success': bool,
    'barcode': String?,     // barcode value
    'format': String?,      // EAN_13, UPC_A, etc.
    'error': String?        // error message if failed
  };
}

// NEW - Photo capture
Future<Map<String, dynamic>> capturePhoto({
  int quality = 85,         // JPEG quality 0-100
  int maxWidth = 1920,      // max photo width
  int maxHeight = 1080,     // max photo height
  bool saveToGallery = false
}) async {
  return {
    'success': bool,
    'photoUri': String?,      // file:// path (always provided)
    'photoBase64': String?,   // base64 (only if small image)
    'timestamp': int?,        // capture time (ms since epoch)
    'width': int?,            // actual photo width
    'height': int?,           // actual photo height
    'fileSize': int?,         // bytes
    'error': String?          // error message if failed
  };
}

// NEW - Photo deletion (for cleanup)
Future<Map<String, dynamic>> deletePhoto({
  required String photoUri
}) async {
  return {
    'success': bool,
    'error': String?
  };
}
```

### Implementation Impact

**NEW Code Required**:
- Photo bridge extension: ~150 lines
- Photo capture service: ~200 lines
- Photo capture screen: ~300 lines
- Photo storage service: ~180 lines
- Thumbnail generator: ~80 lines
- React photo UI: ~150 lines
- **Total: ~1060 lines new code**

**Modified Code**:
- main.dart: +5 lines (register photo bridge)
- shell_bridge.dart: +15 lines (route capturePhoto/deletePhoto)
- pubspec.yaml: +2 lines (camera, image plugins)
- index.html: +150 lines (photo UI)

**Testing Required**:
- 17 new acceptance criteria
- Manual device testing: ~45 minutes
- Photo capture on Android/iOS
- Photo storage verification
- Thumbnail generation verification
- Photo cleanup verification

**Dependencies**:
- `camera: ^0.10.0` - Flutter camera plugin (~8MB APK size)
- `image: ^4.0.0` - Image manipulation for thumbnails (~2MB APK size)
- Total APK size increase: ~10MB (acceptable per AC-5.11)

**Risks**:
- MEDIUM: Camera plugin different from mobile_scanner (learning curve)
- LOW: Photo storage management (standard file I/O)
- LOW: Thumbnail generation (well-documented image package)
- MEDIUM: React photo gallery UI (new UI complexity)

---

## Recommendation

**Route to**: PLANNER for Phase 5.1 planning

**Action**: Create Phase 5.1 plan document (following same schema as phase-5 plan.md) with:
1. Updated requirements (REQ-F9 through REQ-F15, REQ-T7 through REQ-T12)
2. Architecture for TWO bridge methods (scanBarcode + capturePhoto)
3. Flutter photo capture components (5 new files)
4. React photo UI (thumbnails, modal, gallery)
5. Local photo storage architecture
6. 17 new acceptance criteria
7. Dependencies on Phase 5 (camera permissions, bridge patterns)

**Timeline Estimate**: 3-4 hours development + 45 minutes testing

**Alternative**: Merge photo capture into Phase 5 revision (not recommended - Phase 5 already complete and working, better to extend as 5.1)

---

## Next Steps

### For Orchestrator
- [ ] Read this FEEDBACK_REPORT.md
- [ ] Spawn PLANNER with briefing above
- [ ] PLANNER creates phases/phase-5.1-photo-capture/planner/plan.md
- [ ] After PLANNER completes, route to VALIDATOR
- [ ] After validation, route to BUILDER
- [ ] After build, route to REVIEWER (code review)
- [ ] After review, route to TESTER (device testing)
- [ ] After tests pass, write FEEDBACK_RESOLUTION.md

### For Human
- [ ] Review PLANNER's Phase 5.1 plan when ready
- [ ] Approve architecture decisions (photo storage, UI design)
- [ ] Confirm photo retention policy (30 days acceptable?)
- [ ] Confirm max photos per item (5 photos acceptable?)
- [ ] Confirm backend upload out of scope for Phase 5.1
- [ ] Test photo capture on device when implementation complete

---

## Design Questions for Human Approval

### 1. Photo Storage Location
**Question**: Should photos be stored locally only (Phase 5.1) or uploaded to backend immediately?

**Recommendation**: Local storage only in Phase 5.1. Backend upload in Phase 5.2 (separate phase).

**Rationale**: Simpler implementation, faster photo capture, no network dependency during photo taking. Backend upload adds complexity (upload queue, retry logic, offline handling).

**User Decision**: ____________

### 2. Photo Return Format
**Question**: Should capturePhoto() return file URI, base64, or both?

**Recommendation**: Return both. URI for local display (efficient), base64 for future backend upload (portable).

**Rationale**: URI is efficient for React to display via <img src="file://...">. Base64 useful for backend upload without additional bridge call.

**User Decision**: ____________

### 3. Photo Attachment
**Question**: Attach photos to line items, transactions, or standalone gallery?

**Recommendation**: Attach to line items (each line item can have 0-5 photos).

**Rationale**: Photos document specific products/SKUs, not entire transaction. Clerk may receive damaged SKU-123 and perfect SKU-456 in same transaction.

**User Decision**: ____________

### 4. Max Photos Per Item
**Question**: How many photos should user be allowed to capture per line item?

**Recommendation**: 5 photos per line item (front, back, label, damage closeup, packaging).

**Rationale**: Covers most documentation needs without excessive storage. 50 line items × 5 photos × 500KB = 125MB max per transaction (acceptable).

**User Decision**: ____________

### 5. Photo Retention
**Question**: How long should photos be stored locally before cleanup?

**Recommendation**: 30 days retention, auto-cleanup on app start.

**Rationale**: Gives time for transaction review/disputes. After 30 days, transaction is closed and photos not needed. Prevents unbounded storage growth.

**User Decision**: ____________

### 6. Photo Preview/Crop
**Question**: Should user be able to preview/crop photo before accepting?

**Recommendation**: Preview YES (confirm/retake), Crop NO (out of scope for Phase 5.1).

**Rationale**: Preview essential for photo quality confirmation. Crop adds significant UI complexity (crop tool, aspect ratio, etc.) - can be Phase 5.3 if needed.

**User Decision**: ____________

### 7. Photo Gallery View
**Question**: Should there be a gallery view of all photos in a transaction?

**Recommendation**: NO gallery view in Phase 5.1. Thumbnails shown inline with each line item only.

**Rationale**: Inline thumbnails sufficient for MVP. Gallery view adds UI complexity (navigation, sorting, filtering) - can be Phase 5.3 if needed.

**User Decision**: ____________

---

**FEEDBACK STATUS**: Classified and ready for PLANNER routing

**FEEDBACK PRIORITY**: MEDIUM - Feature enhancement (not blocker), but core user requirement

**ESTIMATED EFFORT**: Phase 5.1 — 4-5 hours development + testing
