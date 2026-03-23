# Architecture Design: Barcode Scanning + Photo Capture

**Date**: 2026-03-23
**Phase**: 5 (Barcode) + 5.1 (Photo Capture)
**Status**: Design Complete - Ready for Implementation

---

## Executive Summary

Your warehouse app will have **TWO camera-based features** working side-by-side:

1. **Barcode Scanning** (✅ Already Built) - Scan barcodes to auto-fill product info
2. **Photo Capture** (⏳ To Be Built) - Take photos to document products/damage

Both features share camera permissions but operate independently. No interference between them.

---

## Visual Architecture

### Component Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                      REACT WAREHOUSE UI                             │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │  Line Item Form                                              │   │
│  │  ┌────────────┐  ┌────────────┐  ┌────────────┐            │   │
│  │  │ SKU Input  │  │ [📷 Scan]  │  │ [📸 Photo] │ ← 2 buttons│   │
│  │  └────────────┘  └────────────┘  └────────────┘            │   │
│  │                        ↓                ↓                    │   │
│  │                        │                │                    │   │
│  └────────────────────────┼────────────────┼────────────────────┘   │
└────────────────────────────┼────────────────┼─────────────────────────┘
                             ↓                ↓
┌──────────────────────┬─────────────────────────┬──────────────────────┐
│   shellBridge API    │  scanBarcode()          │  capturePhoto()      │
│   (JavaScript→Dart)  │  (Phase 5 ✅)           │  (Phase 5.1 ⏳)      │
└──────────────────────┴─────────────────────────┴──────────────────────┘
                             ↓                ↓
┌─────────────────────────────────────────────────────────────────────┐
│                      FLUTTER SHELL (Dart)                           │
│  ┌───────────────────────────┐   ┌───────────────────────────────┐ │
│  │  Scanner Bridge Extension │   │  Photo Bridge Extension       │ │
│  │  (scanner_bridge_ext.dart)│   │  (photo_bridge_ext.dart)      │ │
│  │         Phase 5 ✅        │   │        Phase 5.1 ⏳           │ │
│  └───────────┬───────────────┘   └───────────┬───────────────────┘ │
│              ↓                               ↓                      │
│  ┌───────────────────────────┐   ┌───────────────────────────────┐ │
│  │  Barcode Scanner Service  │   │  Photo Capture Service        │ │
│  │  (mobile_scanner plugin)  │   │  (camera plugin)              │ │
│  │         Phase 5 ✅        │   │        Phase 5.1 ⏳           │ │
│  └───────────┬───────────────┘   └───────────┬───────────────────┘ │
│              ↓                               ↓                      │
│  ┌───────────────────────────┐   ┌───────────────────────────────┐ │
│  │  Scanner Screen           │   │  Photo Capture Screen         │ │
│  │  (full-screen camera UI)  │   │  (full-screen camera UI)      │ │
│  │         Phase 5 ✅        │   │        Phase 5.1 ⏳           │ │
│  └───────────┬───────────────┘   └───────────┬───────────────────┘ │
│              ↓                               ↓                      │
│  ┌───────────────────────────────────────────────────────────────┐ │
│  │          Permission Handler Service (Shared) ✅               │ │
│  │          (Requests camera permission for both features)       │ │
│  └───────────────────────────────────────────────────────────────┘ │
│                             ↓                                       │
└─────────────────────────────┼───────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────────┐
│                   DEVICE CAMERA HARDWARE                            │
│  (Accessed by both mobile_scanner and camera plugins separately)   │
└─────────────────────────────────────────────────────────────────────┘
```

---

## How Both Features Work Together

### 1. Shared Components (Reused)

| Component | Purpose | Shared? |
|-----------|---------|---------|
| permission_handler_service.dart | Request camera permission | ✅ YES - Both features use same permission service |
| Camera Hardware | Device camera | ✅ YES - Both access same hardware (but never simultaneously) |
| ShellBridge | Method routing | ✅ YES - Both register methods with same bridge |

### 2. Separate Components (No Interference)

| Component | Barcode (Phase 5) | Photo (Phase 5.1) |
|-----------|-------------------|-------------------|
| Bridge Method | scanBarcode() | capturePhoto() |
| Flutter Plugin | mobile_scanner ^5.0.0 | camera ^0.10.0 |
| Service | barcode_scanner_service.dart | photo_capture_service.dart |
| Screen UI | scanner_screen.dart | photo_capture_screen.dart |
| Data Storage | None (returns barcode string) | photo_storage_service.dart |

**Key Design**: Two separate plugins, two separate services, two separate screens = **Zero interference**

---

## User Flow Comparison

### Barcode Scanning Flow (Phase 5 ✅)

```
User Flow:
1. User taps [📷 Scan] button next to SKU field
2. Camera opens in < 1 second
3. User points camera at barcode
4. Barcode detected (beep sound)
5. Camera closes automatically
6. Form auto-fills:
   - SKU: "WGT-001"
   - Description: "Widget Alpha"
   - Location: "A-01-03"
7. User continues entering quantity

Technical Flow:
React: window.shellBridge.scanBarcode()
  ↓
Dart: scanner_bridge_extension.scanBarcode()
  ↓
Dart: barcode_scanner_service.startScanning()
  ↓
Dart: scanner_screen.dart shows camera
  ↓
Plugin: mobile_scanner detects barcode
  ↓
Dart: Returns {success: true, barcode: "012345678905", format: "EAN_13"}
  ↓
React: Calls backend GET /api/products/012345678905
  ↓
React: Updates form fields with product data
  ↓
User: Sees auto-filled form
```

### Photo Capture Flow (Phase 5.1 ⏳)

```
User Flow:
1. User taps [📸 Photo] button next to SKU field
2. Camera opens in < 2 seconds
3. User takes photo (shutter button)
4. Preview shows captured photo
5. User taps Confirm (or Retake)
6. Camera closes
7. Thumbnail appears in line item row
8. User can click thumbnail to view full-res photo
9. User can delete photo if needed

Technical Flow:
React: window.shellBridge.capturePhoto({quality: 85})
  ↓
Dart: photo_bridge_extension.capturePhoto()
  ↓
Dart: photo_capture_service.openCamera()
  ↓
Dart: photo_capture_screen.dart shows camera
  ↓
User: Taps shutter button
  ↓
Plugin: camera captures image
  ↓
Dart: photo_storage_service saves to /photos/originals/
  ↓
Dart: thumbnail_generator creates 200x200 thumbnail
  ↓
Dart: Returns {success: true, photoUri: "file:///.../photo.jpg", timestamp: ...}
  ↓
React: Updates lineItems[id].photos = [...photos, {uri, timestamp}]
  ↓
React: Displays thumbnail <img src="file://...">
  ↓
User: Sees thumbnail in form
```

---

## Data Flow

### Barcode Scanning (Ephemeral - No Storage)

```
Barcode: "012345678905"
  ↓
Backend Lookup: GET /api/products/012345678905
  ↓
Response: {sku: "WGT-001", name: "Widget Alpha", location: "A-01-03"}
  ↓
React State (temporary):
{
  lineItems: [
    {
      id: 1,
      sku: "WGT-001",          ← Auto-filled from barcode
      description: "Widget Alpha", ← Auto-filled from backend
      quantity: "",            ← User enters manually
      location: "A-01-03"      ← Auto-filled from backend
    }
  ]
}
  ↓
Submit Transaction: POST /api/transactions
  ↓
Backend stores transaction (barcode NOT stored, only resulting SKU)
```

**Key**: Barcode is temporary input, only resulting product data is stored.

### Photo Capture (Persistent - Local Storage)

```
Photo Captured
  ↓
Saved to Disk:
  /photos/originals/2026-03-23_123045_abc123.jpg  (full-res, 500KB)
  /photos/thumbnails/2026-03-23_123045_abc123_thumb.webp  (200x200, 50KB)
  ↓
React State (persistent):
{
  lineItems: [
    {
      id: 1,
      sku: "WGT-001",
      description: "Widget Alpha",
      quantity: 10,
      location: "A-01-03",
      photos: [                              ← NEW: Photo array
        {
          uri: "file:///.../abc123.jpg",
          timestamp: 1711196445000,
          caption: "Damaged corner"          ← Optional
        }
      ]
    }
  ]
}
  ↓
Submit Transaction: POST /api/transactions
  ↓
Backend stores transaction (photos NOT uploaded in Phase 5.1, only local)
  ↓
Photo Cleanup (30 days later):
  Automatically deleted if older than 30 days
```

**Key**: Photos stored locally, NOT sent to backend in Phase 5.1. Backend upload in future Phase 5.2.

---

## React UI Layout

### Line Item Form (Both Features Visible)

```html
Line Item Row:
┌─────────────────────────────────────────────────────────────────────┐
│ SKU:                                                                │
│ ┌─────────────────────┬────────┬────────┐                          │
│ │ [WGT-001          ] │  📷   │  📸   │                          │
│ └─────────────────────┴────────┴────────┘                          │
│                        Scan      Photo                              │
│                        Barcode   Capture                            │
│                                                                     │
│ Description:                                                        │
│ ┌─────────────────────────────────────────────┐                    │
│ │ Widget Alpha                                │                    │
│ └─────────────────────────────────────────────┘                    │
│                                                                     │
│ Quantity:              Location:                                   │
│ ┌──────┐               ┌─────────────────┬────────┐                │
│ │ 10   │               │ A-01-03        │  📱   │                │
│ └──────┘               └─────────────────┴────────┘                │
│                                          Scan QR                    │
│                                                                     │
│ Photos:                                                             │
│ ┌───────┐ ┌───────┐ ┌───────┐ [+ Add Photo]                       │
│ │ 📷    │ │ 📷    │ │ 📷    │                                     │
│ │       │ │       │ │       │                                     │
│ │   🗑️ │ │   🗑️ │ │   🗑️ │ ← Delete buttons                  │
│ └───────┘ └───────┘ └───────┘                                     │
│   Photo 1   Photo 2   Photo 3                                      │
│   Click thumbnail to view full-res                                  │
│                                                                     │
│                                            [× Remove Line Item]     │
└─────────────────────────────────────────────────────────────────────┘

Legend:
📷 = Barcode scan button (Phase 5 ✅)
📸 = Photo capture button (Phase 5.1 ⏳)
📱 = QR scan button (Phase 5 ✅)
🗑️ = Delete photo button (Phase 5.1 ⏳)
```

### React State Structure

```typescript
interface LineItem {
  id: number;

  // Fields from barcode scanning (Phase 5)
  sku: string;              // Auto-filled by scanBarcode() → backend lookup
  description: string;      // Auto-filled by backend lookup
  location: string;         // Auto-filled by scanQRCode() or backend lookup

  // Manual entry
  quantity: number;         // User enters manually

  // NEW: Photo capture (Phase 5.1)
  photos: Array<{
    uri: string;            // "file:///data/.../photo.jpg"
    timestamp: number;      // Unix timestamp (ms)
    caption?: string;       // Optional user caption
  }>;
}

// Example transaction with both features used:
{
  poNumber: "PO-2026-001",
  vendor: "Acme Corp",
  lineItems: [
    {
      id: 1,
      sku: "WGT-001",              // ← From barcode scan
      description: "Widget Alpha", // ← From backend lookup
      quantity: 10,                // ← Manual entry
      location: "A-01-03",         // ← From QR scan
      photos: [                    // ← From photo capture
        {
          uri: "file:///.../photo1.jpg",
          timestamp: 1711196445000,
          caption: "Front view"
        },
        {
          uri: "file:///.../photo2.jpg",
          timestamp: 1711196450000,
          caption: "Damaged corner - see right edge"
        }
      ]
    }
  ]
}
```

---

## Storage Architecture

### Barcode Scanning (No Storage)

Barcode values are **ephemeral** - used for lookup, then discarded.

```
Scan barcode "012345678905"
  ↓
Lookup product from backend
  ↓
Fill form with product data
  ↓
Barcode string NOT stored (only resulting SKU stored in transaction)
```

### Photo Capture (Local Storage)

Photos are **persistent** - saved to local filesystem.

```
Android Storage:
/data/data/com.foundry.shell/app_flutter/photos/
  ├── originals/
  │   ├── 2026-03-23_123045_abc123.jpg     (1920x1080, 450KB)
  │   ├── 2026-03-23_123512_def456.jpg     (1920x1080, 380KB)
  │   └── 2026-03-23_144235_ghi789.jpg     (1920x1080, 510KB)
  ├── thumbnails/
  │   ├── 2026-03-23_123045_abc123_thumb.webp  (200x200, 45KB)
  │   ├── 2026-03-23_123512_def456_thumb.webp  (200x200, 38KB)
  │   └── 2026-03-23_144235_ghi789_thumb.webp  (200x200, 52KB)
  └── .cleanup_timestamp     (last cleanup: 2026-03-23T12:00:00Z)

Retention Policy:
- Photos deleted after 30 days (auto-cleanup on app start)
- Thumbnails deleted with originals
- Cleanup runs in < 2 seconds even with 100+ photos
```

---

## Bridge API Contracts

### Phase 5: Barcode Scanning (Implemented ✅)

```typescript
// Scan product barcode (UPC, EAN, Code 128)
window.shellBridge.scanBarcode(): Promise<{
  success: boolean;
  barcode?: string;    // "012345678905"
  format?: string;     // "EAN_13" | "UPC_A" | "CODE_128" | ...
  error?: string;      // "Camera permission denied" | "Scan cancelled" | ...
}>

// Scan location QR code
window.shellBridge.scanQRCode(): Promise<{
  success: boolean;
  barcode?: string;    // "A-01-03" (QR code value)
  format?: string;     // "QR_CODE"
  error?: string;
}>
```

### Phase 5.1: Photo Capture (To Be Implemented ⏳)

```typescript
// Capture photo of product/damage
window.shellBridge.capturePhoto(options?: {
  quality?: number;      // 0-100, default 85
  maxWidth?: number;     // default 1920
  maxHeight?: number;    // default 1080
}): Promise<{
  success: boolean;
  photoUri?: string;     // "file:///data/.../photo.jpg"
  photoBase64?: string;  // Base64 string (if image < 800px)
  timestamp?: number;    // Unix timestamp (ms)
  width?: number;        // Actual photo width (px)
  height?: number;       // Actual photo height (px)
  fileSize?: number;     // File size (bytes)
  error?: string;        // "Camera permission denied" | "Capture failed" | ...
}>

// Delete photo from storage
window.shellBridge.deletePhoto(params: {
  photoUri: string;      // "file:///data/.../photo.jpg"
}): Promise<{
  success: boolean;
  error?: string;
}>
```

---

## Performance Targets

| Metric | Barcode (Phase 5) | Photo (Phase 5.1) |
|--------|-------------------|-------------------|
| Camera open time | < 1 second | < 2 seconds |
| Operation complete time | < 2 seconds (detection) | < 3 seconds (capture + save) |
| File size | N/A (no storage) | < 500KB per photo |
| Thumbnail generation | N/A | < 200ms per thumbnail |
| Storage cleanup | N/A | < 2 seconds (100+ photos) |
| APK size increase | ~10MB (mobile_scanner) | ~10MB (camera + image) |

---

## Security & Privacy

### Camera Permissions

**Single Permission Request** (Shared):
```
Android: <uses-permission android:name="android.permission.CAMERA"/>
iOS: NSCameraUsageDescription: "Scan barcodes and capture product photos"
```

**Permission Flow**:
1. User taps scan or photo button (first time)
2. App requests camera permission
3. User grants permission
4. Both features now work (no separate permission needed)
5. If user denies: Both features show same error message

### Photo Privacy

**Local Storage Only** (Phase 5.1):
- Photos stored in app-private directory (not accessible to other apps)
- Photos NOT uploaded to backend (no cloud storage)
- Photos NOT visible in device gallery (unless saveToGallery: true)
- Photos deleted after 30 days (automatic cleanup)

**Future Backend Upload** (Phase 5.2):
- Optional upload to backend when transaction submitted
- HTTPS only (encrypted in transit)
- Requires user authentication token
- Backend stores photos with transaction context

---

## Implementation Checklist

### Phase 5 (Barcode Scanning) - ✅ COMPLETE

- [x] scanner_bridge_extension.dart - Bridge methods
- [x] barcode_scanner_service.dart - Scanner service
- [x] scanner_screen.dart - Camera UI
- [x] permission_handler_service.dart - Permissions
- [x] React UI - Scan buttons
- [x] Backend API - Product lookup endpoint
- [x] Testing - 11 acceptance criteria passed

### Phase 5.1 (Photo Capture) - ⏳ TO DO

- [ ] photo_bridge_extension.dart - Bridge methods (capturePhoto, deletePhoto)
- [ ] photo_capture_service.dart - Camera service (camera plugin integration)
- [ ] photo_capture_screen.dart - Camera UI (shutter, preview, confirm/retake)
- [ ] photo_storage_service.dart - File management (save, retrieve, cleanup)
- [ ] thumbnail_generator.dart - Thumbnail creation (200x200 WebP)
- [ ] React UI - Photo button, thumbnail gallery, photo modal
- [ ] Testing - 17 new acceptance criteria + 5 regression tests

### Dependencies (Added to pubspec.yaml)

```yaml
dependencies:
  # Phase 5 (Existing)
  mobile_scanner: ^5.0.0       # ✅ Installed
  permission_handler: ^11.0.0  # ✅ Installed (reused in 5.1)

  # Phase 5.1 (New)
  camera: ^0.10.0              # ⏳ To install
  image: ^4.0.0                # ⏳ To install
  uuid: ^4.0.0                 # ⏳ To install
  path_provider: ^2.0.0        # ⏳ To install
```

---

## Key Design Benefits

### 1. No Interference
- Separate plugins (mobile_scanner vs camera)
- Separate services (barcode_scanner_service vs photo_capture_service)
- Separate screens (scanner_screen vs photo_capture_screen)
- Result: Both features work independently, no conflicts

### 2. Shared Infrastructure
- Same camera permission (permission_handler_service.dart)
- Same bridge pattern (scanner_bridge_extension.dart → photo_bridge_extension.dart)
- Same UI pattern (full-screen camera with controls)
- Result: Consistent UX, code reuse, easier maintenance

### 3. Clear Separation of Concerns
- Barcode scanning = **Data Input** (ephemeral, returns string)
- Photo capture = **Documentation** (persistent, returns file URI)
- Result: Each feature has clear purpose, no ambiguity

### 4. Future-Proof
- Backend upload deferred to Phase 5.2 (not blocker)
- Photo editing deferred to Phase 5.3 (not blocker)
- OCR/intelligence deferred to Phase 5.4 (not blocker)
- Result: Incremental delivery, each phase is useful standalone

---

## Questions Answered

### Q: Will barcode scanning break when I add photo capture?
**A**: NO. Barcode scanning uses mobile_scanner plugin, photo uses camera plugin. Completely separate code paths. Regression tests ensure barcode scanning still works.

### Q: Do I need two camera permission requests?
**A**: NO. Single camera permission covers both features. Permission requested once, works for both.

### Q: Where are photos stored?
**A**: Locally in app's Documents directory (`/data/data/com.foundry.shell/app_flutter/photos/`). NOT uploaded to backend in Phase 5.1. Backend upload in Phase 5.2 (future).

### Q: How many photos can I take?
**A**: Up to 5 photos per line item, unlimited line items. 50 items × 5 photos × 500KB = ~125MB max per transaction.

### Q: How long are photos stored?
**A**: 30 days. Auto-cleanup runs on app start, deletes photos older than 30 days.

### Q: Can I view photos later?
**A**: In Phase 5.1, photos only visible during transaction creation (before submission). After transaction submitted, photos remain in storage for 30 days but not linked to transaction. Phase 5.2 will add backend upload and persistent photo links.

### Q: What if I take a bad photo?
**A**: Preview screen shows photo after capture with Retake button. Can also delete photo from thumbnail gallery.

### Q: Do photos get uploaded to the backend?
**A**: Not in Phase 5.1. Photos stay local only. Phase 5.2 will add optional backend upload when transaction is submitted.

---

## Summary

You will have **TWO independent camera features**:

| Feature | Purpose | Plugin | Storage | Phase |
|---------|---------|--------|---------|-------|
| Barcode Scanning | Auto-fill form data | mobile_scanner | None (ephemeral) | 5 ✅ |
| Photo Capture | Document products | camera | Local (30-day retention) | 5.1 ⏳ |

Both features:
- ✅ Share camera permission
- ✅ Share bridge infrastructure
- ✅ Share UI patterns
- ✅ Work independently (no conflicts)
- ✅ Have clear, separate purposes

**Next Step**: Implement Phase 5.1 (photo capture) following the detailed plan in `plan-updated-photo-capture.md`.

**Estimated Time**: 6-7 hours (planning + build + test)

**Risk Level**: 🟢 LOW - Well-understood technologies, proven patterns, clear requirements
