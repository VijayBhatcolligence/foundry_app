// Phase 5.1: Photo Capture Service
// Purpose: Encapsulates camera plugin integration for still photo capture and compression

import 'dart:io';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;

/// Custom camera service exception (renamed to avoid conflict with camera plugin's CameraServiceException)
class CameraServiceException implements Exception {
  final String message;
  CameraServiceException(this.message);

  @override
  String toString() => 'CameraServiceException: $message';
}

/// Captured photo metadata
class CapturedPhoto {
  final XFile file;
  final int width;
  final int height;
  final int fileSize;
  final DateTime timestamp;

  CapturedPhoto({
    required this.file,
    required this.width,
    required this.height,
    required this.fileSize,
    required this.timestamp,
  });
}

/// Photo Capture Service - Manages camera controller and photo capture
class PhotoCaptureService {
  CameraController? _controller;
  bool _isInitialized = false;

  static const int _maxWidth = 1920;
  static const int _maxHeight = 1080;
  static const int _jpegQuality = 85; // Fixed JPEG quality

  /// Start camera
  Future<void> startCamera() async {
    if (_isInitialized && _controller != null) {
      print('[PhotoCapture] Camera already started');
      return;
    }

    final startTime = DateTime.now();

    try {
      print('[PhotoCapture] Starting camera...');

      // Get available cameras
      final cameras = await availableCameras();

      if (cameras.isEmpty) {
        throw CameraServiceException('No cameras available on this device');
      }

      // Find back camera
      CameraDescription? backCamera;
      for (final camera in cameras) {
        if (camera.lensDirection == CameraLensDirection.back) {
          backCamera = camera;
          break;
        }
      }

      if (backCamera == null) {
        throw CameraServiceException('Back camera not found');
      }

      print('[PhotoCapture] Using camera: ${backCamera.name}');

      // Create controller
      _controller = CameraController(
        backCamera,
        ResolutionPreset.high, // High resolution for still photos
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      // Initialize controller
      await _controller!.initialize();

      _isInitialized = true;

      final duration = DateTime.now().difference(startTime);
      print('[PhotoCapture] Camera opened in ${duration.inMilliseconds}ms');

    } catch (e) {
      final duration = DateTime.now().difference(startTime);
      print('[PhotoCapture] Error after ${duration.inMilliseconds}ms: $e');

      _controller = null;
      _isInitialized = false;

      if (e is CameraServiceException) {
        rethrow;
      } else {
        throw CameraServiceException('Failed to start camera: $e');
      }
    }
  }

  /// Capture photo
  Future<CapturedPhoto> capturePhoto() async {
    if (!_isInitialized || _controller == null) {
      throw CameraServiceException('Camera not started. Call startCamera() first.');
    }

    final captureStartTime = DateTime.now();

    try {
      print('[PhotoCapture] Capturing photo...');

      // Take picture
      final XFile image = await _controller!.takePicture();
      final timestamp = DateTime.now();

      print('[PhotoCapture] Photo captured: ${image.path}');

      // Read image file
      final imageFile = File(image.path);
      final imageBytes = await imageFile.readAsBytes();

      // Decode image to get dimensions
      final decodedImage = img.decodeImage(imageBytes);

      if (decodedImage == null) {
        throw CameraServiceException('Failed to decode captured image');
      }

      final originalWidth = decodedImage.width;
      final originalHeight = decodedImage.height;

      print('[PhotoCapture] Original dimensions: ${originalWidth}x$originalHeight');

      // Check if compression is needed
      bool needsCompression = originalWidth > _maxWidth || originalHeight > _maxHeight;

      XFile finalImage = image;
      int finalWidth = originalWidth;
      int finalHeight = originalHeight;

      if (needsCompression) {
        print('[PhotoCapture] Compressing to ${_maxWidth}x$_maxHeight at $_jpegQuality% quality...');

        // Resize image
        final resizedImage = img.copyResize(
          decodedImage,
          width: originalWidth > originalHeight ? _maxWidth : null,
          height: originalHeight > originalWidth ? _maxHeight : null,
          maintainAspect: true,
        );

        finalWidth = resizedImage.width;
        finalHeight = resizedImage.height;

        print('[PhotoCapture] Resized dimensions: ${finalWidth}x$finalHeight');

        // Encode as JPEG with quality
        final compressedBytes = img.encodeJpg(resizedImage, quality: _jpegQuality);

        // Write compressed image to temporary file
        final tempPath = '${image.path}_compressed.jpg';
        final tempFile = File(tempPath);
        await tempFile.writeAsBytes(compressedBytes);

        finalImage = XFile(tempPath);

        print('[PhotoCapture] Compressed size: ${compressedBytes.length ~/ 1024}KB');
      } else {
        print('[PhotoCapture] No compression needed (already under ${_maxWidth}x$_maxHeight)');
      }

      // Get final file size
      final finalFile = File(finalImage.path);
      final fileSize = await finalFile.length();

      final duration = DateTime.now().difference(captureStartTime);
      print('[PhotoCapture] Photo saved in ${duration.inMilliseconds}ms (${fileSize ~/ 1024}KB)');

      return CapturedPhoto(
        file: finalImage,
        width: finalWidth,
        height: finalHeight,
        fileSize: fileSize,
        timestamp: timestamp,
      );

    } catch (e) {
      final duration = DateTime.now().difference(captureStartTime);
      print('[PhotoCapture] Error after ${duration.inMilliseconds}ms: $e');

      if (e is CameraServiceException) {
        rethrow;
      } else {
        throw CameraServiceException('Failed to capture photo: $e');
      }
    }
  }

  /// Stop camera
  Future<void> stopCamera() async {
    if (_controller == null) {
      print('[PhotoCapture] Camera already stopped');
      return;
    }

    try {
      print('[PhotoCapture] Stopping camera...');
      await _controller!.dispose();
      _controller = null;
      _isInitialized = false;
      print('[PhotoCapture] Camera stopped');
    } catch (e) {
      print('[PhotoCapture] Error stopping camera: $e');
      // Still clear controller reference
      _controller = null;
      _isInitialized = false;
    }
  }

  /// Dispose service
  void dispose() {
    stopCamera();
  }

  /// Get camera controller (for preview)
  CameraController? get controller => _controller;

  /// Check if camera is initialized
  bool get isInitialized => _isInitialized;
}
