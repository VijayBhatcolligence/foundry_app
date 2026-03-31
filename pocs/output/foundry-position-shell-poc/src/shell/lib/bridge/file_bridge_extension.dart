// File Bridge Extension - File operations only (simplified architecture)
// Purpose: Handle file storage separately from action queue
//
// ARCHITECTURE DECISION:
// - Actions (with or without photos) → IndexedDB (React)
// - Photos/files → Flutter file system
// - IndexedDB stores photo_path reference
// - SyncManager reads from IndexedDB, attaches file when syncing

import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// File Bridge Extension - Simplified file operations only
class FileBridgeExtension {
  // Files directory path (lazy loaded)
  String? _filesDir;

  /// Initialize files directory
  Future<void> initialize() async {
    if (_filesDir != null) return;

    try {
      final appDir = await getApplicationDocumentsDirectory();
      _filesDir = path.join(appDir.path, 'files');

      // Create directory if it doesn't exist
      final dir = Directory(_filesDir!);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
        print('[FileBridge] Created files directory: $_filesDir');
      }
    } catch (e) {
      print('[FileBridge] Error initializing files directory: $e');
      throw Exception('Failed to initialize files directory: $e');
    }
  }

  /// Save file from base64 data
  /// Params: { data: string (base64), fileType: string }
  /// Returns: { success: bool, filePath: string, error: string? }
  Future<Map<String, dynamic>> saveFile(Map<String, dynamic> args) async {
    try {
      await initialize();

      if (!args.containsKey('data')) {
        return {
          'success': false,
          'error': 'data (base64) required',
        };
      }

      final base64Data = args['data'] as String;
      final fileType = args['fileType'] as String? ?? 'jpg';

      print('[FileBridge] Saving file (type: $fileType)');

      // Generate unique filename with timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'file_$timestamp.$fileType';
      final filePath = path.join(_filesDir!, fileName);

      // Decode base64
      // Remove data URL prefix if present (e.g., "data:image/jpeg;base64,")
      String cleanBase64 = base64Data;
      if (base64Data.contains(',')) {
        cleanBase64 = base64Data.split(',')[1];
      }

      final bytes = base64Decode(cleanBase64);

      print('[FileBridge] Decoded ${bytes.length} bytes');

      // Write to file
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      print('[FileBridge] ✅ File saved: $filePath (${bytes.length} bytes)');

      return {
        'success': true,
        'filePath': filePath,
        'fileName': fileName,
        'size': bytes.length,
      };

    } catch (e) {
      print('[FileBridge] Error saving file: $e');
      return {
        'success': false,
        'error': 'Failed to save file: ${e.toString()}',
      };
    }
  }

  /// Read file and return as base64
  /// Params: { filePath: string }
  /// Returns: { success: bool, data: string (base64), size: number, error: string? }
  Future<Map<String, dynamic>> readFile(Map<String, dynamic> args) async {
    try {
      if (!args.containsKey('filePath')) {
        return {
          'success': false,
          'error': 'filePath required',
        };
      }

      final filePath = args['filePath'] as String;

      print('[FileBridge] Reading file: $filePath');

      // Remove file:// or file:/// prefix if present
      String cleanPath = filePath;
      if (filePath.startsWith('file://')) {
        cleanPath = filePath.replaceFirst(RegExp(r'^file://+'), '');
      }

      print('[FileBridge] Clean path: $cleanPath');

      // Check if file exists
      final file = File(cleanPath);
      if (!await file.exists()) {
        print('[FileBridge] File not found: $filePath');
        return {
          'success': false,
          'error': 'File not found',
        };
      }

      // Read file bytes
      final bytes = await file.readAsBytes();

      // Encode to base64
      final base64Data = base64Encode(bytes);

      // Get file name
      final fileName = path.basename(cleanPath);

      print('[FileBridge] ✅ File read: $fileName (${bytes.length} bytes)');

      return {
        'success': true,
        'data': base64Data,
        'fileName': fileName,
        'size': bytes.length,
      };

    } catch (e) {
      print('[FileBridge] Error reading file: $e');
      return {
        'success': false,
        'error': 'Failed to read file: ${e.toString()}',
      };
    }
  }

  /// Delete file
  /// Params: { filePath: string }
  /// Returns: { success: bool, error: string? }
  Future<Map<String, dynamic>> deleteFile(Map<String, dynamic> args) async {
    try {
      if (!args.containsKey('filePath')) {
        return {
          'success': false,
          'error': 'filePath required',
        };
      }

      final filePath = args['filePath'] as String;

      print('[FileBridge] Deleting file: $filePath');

      // Remove file:// or file:/// prefix if present
      String cleanPath = filePath;
      if (filePath.startsWith('file://')) {
        cleanPath = filePath.replaceFirst(RegExp(r'^file://+'), '');
      }

      print('[FileBridge] Clean path: $cleanPath');

      // Check if file exists
      final file = File(cleanPath);
      if (!await file.exists()) {
        // Return success for idempotency (file already doesn't exist)
        print('[FileBridge] File already doesn\'t exist: $cleanPath');
        return {
          'success': true,
        };
      }

      // Delete file
      await file.delete();

      print('[FileBridge] ✅ File deleted: $cleanPath');

      return {
        'success': true,
      };

    } catch (e) {
      print('[FileBridge] Error deleting file: $e');
      return {
        'success': false,
        'error': 'Failed to delete file: ${e.toString()}',
      };
    }
  }

  /// List all files in the files directory
  /// Returns: { success: bool, files: [{name: string, path: string, size: number}], error: string? }
  Future<Map<String, dynamic>> listFiles() async {
    try {
      await initialize();

      final dir = Directory(_filesDir!);
      if (!await dir.exists()) {
        return {
          'success': true,
          'files': [],
        };
      }

      final files = <Map<String, dynamic>>[];
      await for (final entity in dir.list()) {
        if (entity is File) {
          final stat = await entity.stat();
          files.add({
            'name': path.basename(entity.path),
            'path': entity.path,
            'size': stat.size,
          });
        }
      }

      print('[FileBridge] Found ${files.length} files');

      return {
        'success': true,
        'files': files,
      };

    } catch (e) {
      print('[FileBridge] Error listing files: $e');
      return {
        'success': false,
        'error': 'Failed to list files: ${e.toString()}',
      };
    }
  }
}
