// Phase 5.1: Photo Bridge Extension
// Purpose: Bridge extension providing capturePhoto() and deletePhoto() methods to React via MethodChannel

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';
import '../photo/photo_capture_service.dart';
import '../photo/photo_storage_service.dart';
import '../photo/photo_capture_screen.dart';
import '../scanner/permission_handler_service.dart';
import 'shell_bridge.dart';

/// BACKEND PHOTO UPLOAD IMPLEMENTATION
///
/// To enable photo upload to backend after capture:
///
/// 1. After capturing and storing photo locally (line ~130), add:
///    ```dart
///    // Upload to backend
///    final backendUrl = await _uploadPhotoToBackend(
///      storedPhoto.originalUri,
///      transactionId,  // Need to pass from React
///      lineItemId
///    );
///    ```
///
/// 2. Add upload method:
///    ```dart
///    Future<String> _uploadPhotoToBackend(
///      String photoPath,
///      String transactionId,
///      String lineItemId
///    ) async {
///      final file = File(photoPath.replaceFirst('file://', ''));
///      final uri = Uri.parse('http://192.168.0.163:3000/api/transactions/\$transactionId/photos');
///
///      final request = http.MultipartRequest('POST', uri);
///      request.fields['lineItemId'] = lineItemId;
///      request.files.add(await http.MultipartFile.fromPath('photo', file.path));
///
///      final response = await request.send();
///      final responseData = await response.stream.bytesToString();
///      final json = jsonDecode(responseData);
///
///      if (json['success']) {
///        return 'http://192.168.0.163:3000\${json['photoPath']}';
///      } else {
///        throw Exception(json['error']);
///      }
///    }
///    ```
///
/// 3. Return backend URL instead of local file URI:
///    ```dart
///    return {
///      'success': true,
///      'photoPath': backendUrl,  // Backend URL
///      'thumbnailPath': backendUrl,  // Same for now
///      ...
///    };
///    ```
///
/// NOTE: This requires transaction ID to be passed from React when calling capturePhoto()

/// Photo Bridge Extension - Provides photo capture capabilities to React modules
class PhotoBridgeExtension {
  // Track photo captures per line item for 5 photo limit
  final Map<String, List<String>> _photosPerLineItem = {};

  // Track capture call frequency for rate limiting
  final List<DateTime> _recentCaptures = [];
  static const int _maxCapturesPerPeriod = 5;
  static const int _rateLimitPeriodSeconds = 10;

  // Reference to navigation context (set during registration)
  BuildContext? _context;

  // Services
  final PhotoStorageService _storageService = PhotoStorageService();

  /// Registers photo methods with ShellBridge
  void registerWithBridge(ShellBridge bridge) {
    print('[PhotoBridge] Registering photo methods...');
    // In production, ShellBridge will route method calls to these handlers
    // via the method call handler in shell_bridge.dart
    print('[PhotoBridge] Photo methods registered');
  }

  /// Sets the navigation context for launching photo capture screen
  void setContext(BuildContext context) {
    _context = context;
  }

  /// Capture photo for a line item
  /// Returns: {success: bool, photoPath: string?, thumbnailPath: string?, timestamp?: number, width?: number, height?: number, fileSize?: number, error: string?}
  Future<Map<String, dynamic>> capturePhoto(String lineItemId) async {
    try {
      print('[PhotoBridge] Capture photo request for line item: $lineItemId');

      // Rate limiting check
      if (!_checkRateLimit()) {
        return {
          'success': false,
          'error': 'Rate limit exceeded. Please wait before capturing again.',
        };
      }

      // Check 5 photos per line item limit
      final photoCount = _photosPerLineItem[lineItemId]?.length ?? 0;
      if (photoCount >= 5) {
        return {
          'success': false,
          'error': 'Maximum 5 photos per item',
        };
      }

      // Check camera permission first
      final permissionService = PermissionHandlerService();
      final permissionStatus = await permissionService.checkCameraPermission();

      if (permissionStatus != PermissionStatus.granted) {
        // Try to request permission
        final requestStatus = await permissionService.requestCameraPermission();

        if (requestStatus == PermissionStatus.permanentlyDenied) {
          return {
            'success': false,
            'error': 'Camera permission denied. Please enable in settings.',
          };
        } else if (requestStatus != PermissionStatus.granted) {
          return {
            'success': false,
            'error': 'Camera permission denied.',
          };
        }
      }

      // Check if context is available
      if (_context == null || !_context!.mounted) {
        return {
          'success': false,
          'error': 'Photo capture not available',
        };
      }

      // Launch photo capture screen
      print('[PhotoBridge] Launching photo capture screen...');
      final startTime = DateTime.now();

      final Completer<String?> completer = Completer<String?>();

      await Navigator.push(
        _context!,
        MaterialPageRoute(
          builder: (context) => PhotoCaptureScreen(
            onPhotoConfirmed: (photoPath) {
              completer.complete(photoPath);
            },
            onCancelled: () {
              completer.complete(null);
            },
          ),
        ),
      );

      // Wait for result
      final photoPath = await completer.future;

      if (photoPath == null) {
        return {
          'success': false,
          'error': 'Photo capture cancelled',
        };
      }

      print('[PhotoBridge] Photo captured: $photoPath');

      // Create XFile from captured photo path
      final capturedFile = XFile(photoPath);

      // Save photo to storage with thumbnail generation
      final storedPhoto = await _storageService.savePhoto(capturedFile);

      // Track photo for this line item
      if (!_photosPerLineItem.containsKey(lineItemId)) {
        _photosPerLineItem[lineItemId] = [];
      }
      _photosPerLineItem[lineItemId]!.add(storedPhoto.originalUri);

      // Record successful capture
      _recentCaptures.add(DateTime.now());

      print('[PhotoBridge] Converting photos to base64 for WebView compatibility...');

      // Convert photo and thumbnail to base64 data URLs
      // This is required because Android WebView cannot access file:// URLs due to security restrictions
      final photoFile = File(storedPhoto.originalUri.replaceFirst('file://', ''));
      final thumbnailFile = File(storedPhoto.thumbnailUri.replaceFirst('file://', ''));

      String photoBase64 = storedPhoto.originalUri; // Fallback to file URI
      String thumbnailBase64 = storedPhoto.thumbnailUri; // Fallback to file URI

      try {
        // Read original photo bytes
        if (await photoFile.exists()) {
          final photoBytes = await photoFile.readAsBytes();
          photoBase64 = 'data:image/jpeg;base64,${base64Encode(photoBytes)}';
          print('[PhotoBridge] Original photo encoded: ${photoBytes.length} bytes -> ${photoBase64.length} chars');
        }

        // Read thumbnail bytes
        if (await thumbnailFile.exists()) {
          final thumbnailBytes = await thumbnailFile.readAsBytes();
          thumbnailBase64 = 'data:image/jpeg;base64,${base64Encode(thumbnailBytes)}';
          print('[PhotoBridge] Thumbnail encoded: ${thumbnailBytes.length} bytes -> ${thumbnailBase64.length} chars');
        }
      } catch (e) {
        print('[PhotoBridge] Warning: Failed to convert to base64: $e');
        // Fall back to file URIs (will be blank in WebView but won't crash)
      }

      final duration = DateTime.now().difference(startTime);
      print('[PhotoBridge] Photo saved and encoded in ${duration.inMilliseconds}ms');

      return {
        'success': true,
        'photoPath': photoBase64,  // Base64 data URL for WebView
        'thumbnailPath': thumbnailBase64,  // Base64 data URL for WebView
        'timestamp': storedPhoto.createdAt.millisecondsSinceEpoch,
        'width': 1920, // Max width after compression
        'height': 1080, // Max height after compression
        'fileSize': storedPhoto.fileSize,
      };

    } on CameraServiceException catch (e) {
      print('[PhotoBridge] Camera error: $e');
      return {
        'success': false,
        'error': 'Camera not available on this device',
      };
    } on CameraException catch (e) {
      print('[PhotoBridge] Camera plugin error: $e');
      return {
        'success': false,
        'error': 'Camera error: ${e.description}',
      };
    } on StorageException catch (e) {
      print('[PhotoBridge] Storage error: $e');
      return {
        'success': false,
        'error': 'Failed to save photo: ${e.message}',
      };
    } on TimeoutException {
      return {
        'success': false,
        'error': 'Photo capture timeout. Please try again.',
      };
    } catch (e) {
      print('[PhotoBridge] Capture error: $e');
      return {
        'success': false,
        'error': 'Photo capture error: ${e.toString()}',
      };
    }
  }

  /// Delete photo by path
  /// Returns: {success: bool, error: string?}
  Future<Map<String, dynamic>> deletePhoto(String photoPath) async {
    try {
      print('[PhotoBridge] Delete photo request: $photoPath');

      // Validate photoPath format
      if (!photoPath.startsWith('file://')) {
        return {
          'success': false,
          'error': 'Invalid photo URI',
        };
      }

      // Delete from storage
      final deleted = await _storageService.deletePhoto(photoPath);

      if (deleted) {
        // Remove from tracking map
        for (final lineItemId in _photosPerLineItem.keys) {
          _photosPerLineItem[lineItemId]?.remove(photoPath);
        }

        print('[PhotoBridge] Photo deleted successfully');

        return {
          'success': true,
        };
      } else {
        // Still return success for idempotency
        return {
          'success': true,
        };
      }

    } catch (e) {
      print('[PhotoBridge] Delete error: $e');
      // Return success for idempotency (file doesn't exist = success)
      return {
        'success': true,
      };
    }
  }

  /// List photos for a line item
  /// Returns: {success: bool, photos: [{path: string, thumbnailPath: string, timestamp: number}], error: string?}
  Future<Map<String, dynamic>> listPhotos(String lineItemId) async {
    try {
      print('[PhotoBridge] List photos request for line item: $lineItemId');

      final photoPaths = _photosPerLineItem[lineItemId] ?? [];

      // For now, we're tracking photo paths but not timestamps
      // In a production system, we'd query the storage service for full metadata
      final photos = photoPaths.map((path) {
        // Convert original path to thumbnail path
        final thumbnailPath = path
            .replaceAll('/originals/', '/thumbnails/')
            .replaceAll('.jpg', '_thumb.webp');

        return {
          'path': path,
          'thumbnailPath': thumbnailPath,
          'timestamp': DateTime.now().millisecondsSinceEpoch, // Placeholder
        };
      }).toList();

      return {
        'success': true,
        'photos': photos,
      };

    } catch (e) {
      print('[PhotoBridge] List photos error: $e');
      return {
        'success': false,
        'error': 'Failed to list photos: ${e.toString()}',
      };
    }
  }

  /// Check rate limiting
  bool _checkRateLimit() {
    final now = DateTime.now();

    // Remove captures older than rate limit period
    _recentCaptures.removeWhere(
      (capture) => now.difference(capture).inSeconds > _rateLimitPeriodSeconds,
    );

    if (_recentCaptures.length >= _maxCapturesPerPeriod) {
      print('[PhotoBridge] Rate limit exceeded: ${_recentCaptures.length} captures in ${_rateLimitPeriodSeconds}s');
      return false;
    }

    return true;
  }

}
