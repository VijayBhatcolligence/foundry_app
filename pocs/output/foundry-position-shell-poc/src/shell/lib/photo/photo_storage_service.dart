// Phase 5.1: Photo Storage Service
// Purpose: Photo file management including save, retrieve, delete, and 30-day cleanup

import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:camera/camera.dart';
import 'thumbnail_generator.dart';

/// Storage exception
class StorageException implements Exception {
  final String message;
  StorageException(this.message);

  @override
  String toString() => 'StorageException: $message';
}

/// Stored photo metadata
class StoredPhoto {
  final String originalUri;
  final String thumbnailUri;
  final String filename;
  final int fileSize;
  final DateTime createdAt;

  StoredPhoto({
    required this.originalUri,
    required this.thumbnailUri,
    required this.filename,
    required this.fileSize,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'originalUri': originalUri,
    'thumbnailUri': thumbnailUri,
    'filename': filename,
    'fileSize': fileSize,
    'timestamp': createdAt.millisecondsSinceEpoch,
  };
}

/// Photo Storage Service - Manages photo file operations
class PhotoStorageService {
  final ThumbnailGenerator _thumbnailGenerator = ThumbnailGenerator();
  final Uuid _uuid = const Uuid();

  static const String _photosDir = 'photos';
  static const String _originalsSubdir = 'originals';
  static const String _thumbnailsSubdir = 'thumbnails';
  static const int _retentionDays = 30;

  /// Get base photos directory path
  Future<Directory> _getPhotosDirectory() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final photosDir = Directory('${appDocDir.path}/$_photosDir');

    if (!await photosDir.exists()) {
      await photosDir.create(recursive: true);
    }

    return photosDir;
  }

  /// Get originals directory
  Future<Directory> _getOriginalsDirectory() async {
    final photosDir = await _getPhotosDirectory();
    final originalsDir = Directory('${photosDir.path}/$_originalsSubdir');

    if (!await originalsDir.exists()) {
      await originalsDir.create(recursive: true);
    }

    return originalsDir;
  }

  /// Get thumbnails directory
  Future<Directory> _getThumbnailsDirectory() async {
    final photosDir = await _getPhotosDirectory();
    final thumbnailsDir = Directory('${photosDir.path}/$_thumbnailsSubdir');

    if (!await thumbnailsDir.exists()) {
      await thumbnailsDir.create(recursive: true);
    }

    return thumbnailsDir;
  }

  /// Generate unique filename: YYYY-MM-DD_HHMMSS_{uuid8}.jpg
  String _generateFilename() {
    final now = DateTime.now();
    final timestamp = '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}';

    // Generate 8-character UUID
    final uuid8 = _uuid.v4().substring(0, 8);

    return '${timestamp}_$uuid8';
  }

  /// Save photo to storage with thumbnail generation
  Future<StoredPhoto> savePhoto(XFile photo) async {
    final startTime = DateTime.now();

    try {
      print('[PhotoStorage] Saving photo: ${photo.path}');

      // Get storage directories
      final originalsDir = await _getOriginalsDirectory();
      final thumbnailsDir = await _getThumbnailsDirectory();

      // Generate unique filename
      final filename = _generateFilename();
      final originalFilename = '$filename.jpg';
      final thumbnailFilename = '${filename}_thumb.webp';

      // Copy photo to originals directory
      final originalPath = '${originalsDir.path}/$originalFilename';
      final photoFile = File(photo.path);

      if (!await photoFile.exists()) {
        throw StorageException('Source photo file does not exist: ${photo.path}');
      }

      // Copy file
      await photoFile.copy(originalPath);

      // Verify file was copied
      final originalFile = File(originalPath);
      if (!await originalFile.exists()) {
        throw StorageException('Failed to copy photo to storage');
      }

      final fileSize = await originalFile.length();
      print('[PhotoStorage] Original saved: $originalPath (${fileSize ~/ 1024}KB)');

      // Generate thumbnail path
      final thumbnailPath = '${thumbnailsDir.path}/$thumbnailFilename';

      // Generate thumbnail asynchronously
      try {
        await _thumbnailGenerator.generateThumbnail(originalPath, thumbnailPath);
      } catch (e) {
        // Log warning but don't fail - original is still saved
        print('[PhotoStorage] Warning: Thumbnail generation failed: $e');
        // Create a placeholder thumbnail path
      }

      final createdAt = DateTime.now();

      // Create URIs
      final originalUri = 'file://$originalPath';
      final thumbnailUri = 'file://$thumbnailPath';

      final duration = DateTime.now().difference(startTime);
      print('[PhotoStorage] Photo saved in ${duration.inMilliseconds}ms');

      return StoredPhoto(
        originalUri: originalUri,
        thumbnailUri: thumbnailUri,
        filename: originalFilename,
        fileSize: fileSize,
        createdAt: createdAt,
      );

    } catch (e) {
      final duration = DateTime.now().difference(startTime);
      print('[PhotoStorage] Error after ${duration.inMilliseconds}ms: $e');

      if (e is StorageException) {
        rethrow;
      } else {
        throw StorageException('Failed to save photo: $e');
      }
    }
  }

  /// Delete photo by URI (deletes both original and thumbnail)
  Future<bool> deletePhoto(String photoUri) async {
    try {
      print('[PhotoStorage] Deleting photo: $photoUri');

      // Convert URI to path
      final photoPath = photoUri.replaceFirst('file://', '');
      final photoFile = File(photoPath);

      // Check if it's an original or thumbnail
      final isOriginal = photoPath.contains('/$_originalsSubdir/');
      final isThumbnail = photoPath.contains('/$_thumbnailsSubdir/');

      if (!isOriginal && !isThumbnail) {
        print('[PhotoStorage] Warning: Photo URI not in expected directory: $photoUri');
        return false;
      }

      // Delete the specified file
      if (await photoFile.exists()) {
        await photoFile.delete();
        print('[PhotoStorage] Deleted: $photoPath');
      } else {
        print('[PhotoStorage] File does not exist (already deleted?): $photoPath');
      }

      // If deleting original, also delete corresponding thumbnail
      if (isOriginal) {
        final filename = photoFile.uri.pathSegments.last;
        final baseFilename = filename.replaceAll('.jpg', '');
        final thumbnailFilename = '${baseFilename}_thumb.webp';

        final thumbnailsDir = await _getThumbnailsDirectory();
        final thumbnailPath = '${thumbnailsDir.path}/$thumbnailFilename';
        final thumbnailFile = File(thumbnailPath);

        if (await thumbnailFile.exists()) {
          await thumbnailFile.delete();
          print('[PhotoStorage] Deleted thumbnail: $thumbnailPath');
        }
      }

      // If deleting thumbnail, also delete corresponding original
      if (isThumbnail) {
        final filename = photoFile.uri.pathSegments.last;
        final baseFilename = filename.replaceAll('_thumb.webp', '');
        final originalFilename = '$baseFilename.jpg';

        final originalsDir = await _getOriginalsDirectory();
        final originalPath = '${originalsDir.path}/$originalFilename';
        final originalFile = File(originalPath);

        if (await originalFile.exists()) {
          await originalFile.delete();
          print('[PhotoStorage] Deleted original: $originalPath');
        }
      }

      return true;

    } catch (e) {
      print('[PhotoStorage] Error deleting photo: $e');
      // Return true for idempotency (file doesn't exist = success)
      return true;
    }
  }

  /// Clean up old photos (older than 30 days)
  Future<int> cleanupOldPhotos() async {
    final startTime = DateTime.now();
    int deletedCount = 0;

    try {
      print('[PhotoStorage] Starting cleanup (retention: $_retentionDays days)...');

      final now = DateTime.now();
      final cutoffDate = now.subtract(Duration(days: _retentionDays));

      // Get directories
      final originalsDir = await _getOriginalsDirectory();
      final thumbnailsDir = await _getThumbnailsDirectory();

      // Cleanup originals
      final originalFiles = originalsDir.listSync();
      for (final file in originalFiles) {
        if (file is File) {
          final stat = await file.stat();
          final createdDate = stat.modified; // Use modified as proxy for created

          if (createdDate.isBefore(cutoffDate)) {
            await file.delete();
            deletedCount++;
            print('[PhotoStorage] Deleted old original: ${file.path}');
          }
        }
      }

      // Cleanup thumbnails
      final thumbnailFiles = thumbnailsDir.listSync();
      for (final file in thumbnailFiles) {
        if (file is File) {
          final stat = await file.stat();
          final createdDate = stat.modified;

          if (createdDate.isBefore(cutoffDate)) {
            await file.delete();
            deletedCount++;
            print('[PhotoStorage] Deleted old thumbnail: ${file.path}');
          }
        }
      }

      final duration = DateTime.now().difference(startTime);
      print('[PhotoStorage] Cleanup completed in ${duration.inMilliseconds}ms: $deletedCount old photos deleted');

      return deletedCount;

    } catch (e) {
      final duration = DateTime.now().difference(startTime);
      print('[PhotoStorage] Cleanup error after ${duration.inMilliseconds}ms: $e');
      return deletedCount;
    }
  }

  /// Get photo path by filename
  Future<String> getPhotoPath(String filename) async {
    final originalsDir = await _getOriginalsDirectory();
    return '${originalsDir.path}/$filename';
  }
}
