# Blank Photo Fix - Test Checklist

**Patch**: 003-blank-photo-fix
**Date**: 2026-03-23
**Tester**: _________

## Pre-Testing Setup

- [ ] Build app with updated code: `flutter build apk` or `flutter run`
- [ ] Deploy to physical Android device (emulator may have different WebView behavior)
- [ ] Clear app data to ensure clean state
- [ ] Verify camera permission granted

## Test Cases

### Test 1: Single Photo Capture
**Steps**:
1. Open Warehouse Clerk app
2. Add a line item
3. Tap camera button (📸) next to SKU field
4. Take a photo and confirm
5. **EXPECTED**: Thumbnail appears immediately (NOT BLANK)
6. Check console logs for base64 encoding confirmation

**Result**: ⬜ PASS | ⬜ FAIL
**Notes**: _________________________________

---

### Test 2: View Full-Size Photo
**Steps**:
1. After Test 1, tap the thumbnail
2. **EXPECTED**: Modal opens with full-size photo (NOT BLANK)
3. Close modal
4. Photo should still be visible in gallery

**Result**: ⬜ PASS | ⬜ FAIL
**Notes**: _________________________________

---

### Test 3: Multiple Photos (5 Photo Limit)
**Steps**:
1. Continue from Test 2
2. Capture 4 more photos (total 5)
3. **EXPECTED**: All 5 thumbnails display correctly
4. Tap each thumbnail to verify full-size photos work
5. Try to capture 6th photo - should be disabled/error

**Result**: ⬜ PASS | ⬜ FAIL
**Notes**: _________________________________

---

### Test 4: Photo Deletion
**Steps**:
1. Continue from Test 3
2. Tap delete button (🗑️) on 2nd photo thumbnail
3. **EXPECTED**: Photo removed from gallery
4. Verify only 4 photos remain
5. Verify camera button re-enabled (since < 5 photos)

**Result**: ⬜ PASS | ⬜ FAIL
**Notes**: _________________________________

---

### Test 5: Transaction Submission with Photos
**Steps**:
1. Fill in all line item fields (SKU, Description, Quantity, Location)
2. Fill in PO Number and Vendor
3. Submit transaction
4. **EXPECTED**: Success message
5. Switch to History tab
6. Find submitted transaction
7. **EXPECTED**: Photos display in history view

**Result**: ⬜ PASS | ⬜ FAIL
**Notes**: _________________________________

---

### Test 6: Performance Check
**Steps**:
1. Start new transaction
2. Add line item
3. Note time before capturing photo
4. Capture photo
5. Note time when thumbnail appears
6. **EXPECTED**: < 1 second total capture + encode time

**Result**: ⬜ PASS | ⬜ FAIL
**Capture Time**: _______ ms
**Notes**: _________________________________

---

### Test 7: Console Log Verification
**Expected Logs** (check Android Studio logcat or `flutter logs`):
```
[PhotoBridge] Photo captured: /data/user/0/.../temp.jpg
[PhotoBridge] Converting photos to base64 for WebView compatibility...
[PhotoBridge] Original photo encoded: 245123 bytes -> 326832 chars
[PhotoBridge] Thumbnail encoded: 18456 bytes -> 24608 chars
[PhotoBridge] Photo saved and encoded in 687ms
```

**Result**: ⬜ PASS | ⬜ FAIL
**Logs Present**: ⬜ YES | ⬜ NO
**Notes**: _________________________________

---

## Edge Cases

### Test 8: Low Memory Device
**Steps**:
1. Capture 5 photos on a low-memory device
2. **EXPECTED**: No crashes or out-of-memory errors
3. Check memory usage in Android Studio profiler

**Result**: ⬜ PASS | ⬜ FAIL | ⬜ N/A
**Notes**: _________________________________

---

### Test 9: Rapid Photo Capture
**Steps**:
1. Quickly capture 5 photos in succession
2. **EXPECTED**: All display correctly
3. No missing thumbnails
4. No duplicate photos

**Result**: ⬜ PASS | ⬜ FAIL
**Notes**: _________________________________

---

### Test 10: App Background/Foreground
**Steps**:
1. Capture 2 photos
2. Press home button (app goes to background)
3. Reopen app
4. **EXPECTED**: Photos still visible
5. Capture another photo
6. **EXPECTED**: New photo displays correctly

**Result**: ⬜ PASS | ⬜ FAIL
**Notes**: _________________________________

---

## Regression Tests

### Test 11: Photo Storage Files
**Steps**:
1. Capture a photo
2. Use Android Studio Device File Explorer
3. Navigate to `/data/data/com.example.app/files/photos/`
4. **EXPECTED**:
   - Original JPEG exists in `/originals/`
   - Thumbnail exists in `/thumbnails/`
5. Verify files are NOT corrupted (can open in image viewer)

**Result**: ⬜ PASS | ⬜ FAIL
**Notes**: _________________________________

---

### Test 12: Delete Photo File Cleanup
**Steps**:
1. Capture a photo
2. Note filename in console logs
3. Delete photo via UI
4. Check file system
5. **EXPECTED**: Both original and thumbnail files deleted

**Result**: ⬜ PASS | ⬜ FAIL
**Notes**: _________________________________

---

## Issue Tracking

### Bugs Found
| # | Description | Severity | Status |
|---|-------------|----------|--------|
| 1 |             |          |        |
| 2 |             |          |        |
| 3 |             |          |        |

---

## Sign-Off

**All Critical Tests Pass**: ⬜ YES | ⬜ NO

**Blocker Issues**: ⬜ NONE | ⬜ FOUND (list above)

**Ready for Production**: ⬜ YES | ⬜ NO

**Tester Signature**: _________________ **Date**: _________

**Reviewer Signature**: _________________ **Date**: _________

---

## Rollback Procedure (If Needed)

If photos are still blank or new issues arise:

1. Open `photo_bridge_extension.dart`
2. Locate lines 197-232 (base64 encoding block)
3. Replace return statement with:
```dart
return {
  'success': true,
  'photoPath': storedPhoto.originalUri,
  'thumbnailPath': storedPhoto.thumbnailUri,
  'timestamp': storedPhoto.createdAt.millisecondsSinceEpoch,
  'width': 1920,
  'height': 1080,
  'fileSize': storedPhoto.fileSize,
};
```
4. Rebuild and deploy
5. File bug report with logs
