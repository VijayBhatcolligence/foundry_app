// Phase 5: Permission Handler Service
// Purpose: Manages camera permission requests and status checks across Android API levels

import 'package:permission_handler/permission_handler.dart' as ph;

/// Permission status enum
enum PermissionStatus {
  granted,
  denied,
  permanentlyDenied,
  restricted,
}

/// Permission Handler Service - Manages camera permissions
class PermissionHandlerService {
  DateTime? _lastRequestTime;
  static const int _requestDebounceMs = 1000; // 1 second debounce

  /// Check current camera permission status
  Future<PermissionStatus> checkCameraPermission() async {
    try {
      final status = await ph.Permission.camera.status;
      return _convertPermissionStatus(status);
    } catch (e) {
      print('[PermissionHandler] Error checking permission: $e');
      return PermissionStatus.denied;
    }
  }

  /// Request camera permission
  Future<PermissionStatus> requestCameraPermission() async {
    try {
      // Debounce permission requests to prevent dialog spam
      final now = DateTime.now();
      if (_lastRequestTime != null) {
        final timeSinceLastRequest = now.difference(_lastRequestTime!).inMilliseconds;
        if (timeSinceLastRequest < _requestDebounceMs) {
          print('[PermissionHandler] Request debounced');
          return await checkCameraPermission();
        }
      }

      _lastRequestTime = now;

      print('[PermissionHandler] Requesting camera permission...');

      // Check current status
      final currentStatus = await ph.Permission.camera.status;

      if (currentStatus.isGranted) {
        print('[PermissionHandler] Permission already granted');
        return PermissionStatus.granted;
      }

      if (currentStatus.isPermanentlyDenied) {
        print('[PermissionHandler] Permission permanently denied');
        return PermissionStatus.permanentlyDenied;
      }

      if (currentStatus.isRestricted) {
        print('[PermissionHandler] Permission restricted (enterprise device)');
        return PermissionStatus.restricted;
      }

      // Request permission
      final newStatus = await ph.Permission.camera.request();
      print('[PermissionHandler] Permission request result: $newStatus');

      return _convertPermissionStatus(newStatus);

    } catch (e) {
      print('[PermissionHandler] Error requesting permission: $e');
      return PermissionStatus.denied;
    }
  }

  /// Open app settings
  Future<bool> openAppSettings() async {
    try {
      print('[PermissionHandler] Opening app settings...');
      final opened = await ph.openAppSettings();
      print('[PermissionHandler] App settings opened: $opened');
      return opened;
    } catch (e) {
      print('[PermissionHandler] Error opening settings: $e');
      return false;
    }
  }

  /// Convert permission_handler status to our PermissionStatus enum
  PermissionStatus _convertPermissionStatus(ph.PermissionStatus status) {
    if (status.isGranted) {
      return PermissionStatus.granted;
    } else if (status.isPermanentlyDenied) {
      return PermissionStatus.permanentlyDenied;
    } else if (status.isRestricted) {
      return PermissionStatus.restricted;
    } else {
      return PermissionStatus.denied;
    }
  }
}
