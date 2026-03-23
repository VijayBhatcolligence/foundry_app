// Phase 5.1: Thumbnail Generator
// Purpose: Generate 200x200 JPEG thumbnails asynchronously for efficient display

import 'dart:io';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Thumbnail generation exception
class ThumbnailException implements Exception {
  final String message;
  ThumbnailException(this.message);

  @override
  String toString() => 'ThumbnailException: $message';
}

/// Parameters for thumbnail generation in isolate
class _ThumbnailParams {
  final String originalPath;
  final String thumbnailPath;

  _ThumbnailParams({
    required this.originalPath,
    required this.thumbnailPath,
  });
}

/// Thumbnail Generator - Generates 200x200 JPEG thumbnails
class ThumbnailGenerator {
  static const int _thumbnailSize = 200;
  static const int _jpegQuality = 80; // JPEG quality (0-100)

  /// Generate thumbnail from original photo
  /// Uses compute() for async processing to avoid blocking UI thread
  Future<void> generateThumbnail(String originalPath, String thumbnailPath) async {
    final startTime = DateTime.now();

    try {
      print('[Thumbnail] Generating thumbnail for: $originalPath');

      // Check if original file exists
      final originalFile = File(originalPath);
      if (!await originalFile.exists()) {
        throw ThumbnailException('Original file does not exist: $originalPath');
      }

      // Check if file is readable
      final fileSize = await originalFile.length();
      if (fileSize == 0) {
        throw ThumbnailException('Original file is empty: $originalPath');
      }

      print('[Thumbnail] Original file size: ${fileSize ~/ 1024}KB');

      // Generate thumbnail in background isolate
      final params = _ThumbnailParams(
        originalPath: originalPath,
        thumbnailPath: thumbnailPath,
      );

      await compute(_generateThumbnailInIsolate, params);

      final duration = DateTime.now().difference(startTime);
      print('[Thumbnail] Thumbnail generated in ${duration.inMilliseconds}ms: $thumbnailPath');

      // Verify thumbnail was created
      final thumbnailFile = File(thumbnailPath);
      if (!await thumbnailFile.exists()) {
        throw ThumbnailException('Thumbnail file was not created');
      }

      final thumbnailSize = await thumbnailFile.length();
      print('[Thumbnail] Thumbnail size: ${thumbnailSize ~/ 1024}KB');

    } catch (e) {
      final duration = DateTime.now().difference(startTime);
      print('[Thumbnail] Error after ${duration.inMilliseconds}ms: $e');

      if (e is ThumbnailException) {
        rethrow;
      } else {
        throw ThumbnailException('Failed to generate thumbnail: $e');
      }
    }
  }

  /// Generate thumbnail in isolate (runs on background thread)
  static Future<void> _generateThumbnailInIsolate(_ThumbnailParams params) async {
    try {
      // Read original image file
      final originalFile = File(params.originalPath);
      final imageBytes = await originalFile.readAsBytes();

      // Decode image
      img.Image? image;
      try {
        image = img.decodeImage(imageBytes);
      } catch (e) {
        throw ThumbnailException('Failed to decode image (corrupted file?): $e');
      }

      if (image == null) {
        throw ThumbnailException('Failed to decode image (unsupported format?)');
      }

      print('[Thumbnail] Original dimensions: ${image.width}x${image.height}');

      // Resize to thumbnail size (maintain aspect ratio)
      // Use copyResize with fit inside mode to maintain aspect ratio
      final thumbnail = img.copyResize(
        image,
        width: _thumbnailSize,
        height: _thumbnailSize,
        maintainAspect: true,
      );

      print('[Thumbnail] Thumbnail dimensions: ${thumbnail.width}x${thumbnail.height}');

      // Encode as JPEG (compatible with image package v4.0+)
      final jpegBytes = img.encodeJpg(thumbnail, quality: _jpegQuality);

      // Create thumbnail directory if it doesn't exist
      final thumbnailFile = File(params.thumbnailPath);
      final thumbnailDir = thumbnailFile.parent;
      if (!await thumbnailDir.exists()) {
        await thumbnailDir.create(recursive: true);
      }

      // Write thumbnail file
      await thumbnailFile.writeAsBytes(jpegBytes);

      print('[Thumbnail] Thumbnail saved: ${params.thumbnailPath}');

    } catch (e) {
      if (e is ThumbnailException) {
        rethrow;
      }
      throw ThumbnailException('Thumbnail generation failed: $e');
    }
  }
}
