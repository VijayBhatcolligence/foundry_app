// Module HTTP Server - Per-module server instance
// Part of Parallel Modules Architecture
// Each module gets its own HTTP server on a unique port

import 'dart:io';
import 'dart:async';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../config/modules_config.dart';

class ModuleHttpServer {
  final ModuleConfig config;
  HttpServer? _server;
  bool _isRunning = false;
  String? _tempModulePath;

  ModuleHttpServer(this.config);

  /// Returns true if server is currently running
  bool get isRunning => _isRunning;

  /// Returns the allocated port
  int get port => config.port;

  /// Returns the base URL (e.g., "http://localhost:8080")
  String get baseUrl => config.getUrl();

  /// Returns the module origin (for IndexedDB)
  String get origin => config.getOrigin();

  /// Returns the temp directory path where module is copied
  String? get tempModulePath => _tempModulePath;

  /// Start the HTTP server for this module
  Future<void> start() async {
    if (_isRunning) {
      print('[ModuleHttpServer:${config.id}] Server already running on port ${config.port}');
      return;
    }

    try {
      print('[ModuleHttpServer:${config.id}] Starting server on port ${config.port}...');

      // Step 1: Copy module assets to temp directory
      await _copyModuleAssets();

      // Step 2: Create shelf handler
      final handler = const shelf.Pipeline()
          .addMiddleware(_corsMiddleware())
          .addMiddleware(_loggingMiddleware())
          .addHandler(_handleRequest);

      // Step 3: Start server on specific port
      _server = await shelf_io.serve(
        handler,
        InternetAddress.loopbackIPv4,
        config.port,
      );

      _isRunning = true;

      print('[ModuleHttpServer:${config.id}] ✅ Server started');
      print('[ModuleHttpServer:${config.id}] 📍 URL: $baseUrl');
      print('[ModuleHttpServer:${config.id}] 🔗 Origin: $origin (isolated IndexedDB)');
      print('[ModuleHttpServer:${config.id}] 📁 Path: $_tempModulePath');
    } catch (e) {
      print('[ModuleHttpServer:${config.id}] ❌ Failed to start: $e');

      // If port is busy, try alternative
      if (e.toString().contains('Address already in use')) {
        print('[ModuleHttpServer:${config.id}] Port ${config.port} busy');
        throw Exception('Port ${config.port} already in use for module ${config.id}');
      } else {
        rethrow;
      }
    }
  }

  /// Stop the server
  Future<void> stop() async {
    if (!_isRunning || _server == null) {
      return;
    }

    try {
      print('[ModuleHttpServer:${config.id}] Stopping server...');
      await _server!.close(force: true);
      _server = null;
      _isRunning = false;
      print('[ModuleHttpServer:${config.id}] ✅ Server stopped');
    } catch (e) {
      print('[ModuleHttpServer:${config.id}] ❌ Error stopping: $e');
    }
  }

  /// Copy module assets from Flutter assets to temp directory
  Future<void> _copyModuleAssets() async {
    try {
      print('[ModuleHttpServer:${config.id}] Copying module assets...');

      // Get temp directory
      final tempDir = await getTemporaryDirectory();
      _tempModulePath = path.join(tempDir.path, 'modules', config.id);

      // Create module directory
      final moduleDir = Directory(_tempModulePath!);
      if (await moduleDir.exists()) {
        await moduleDir.delete(recursive: true);
      }
      await moduleDir.create(recursive: true);

      // Copy module files
      await _copyModuleFiles();

      // Copy shared assets
      await _copySharedAssets();

      print('[ModuleHttpServer:${config.id}] ✅ Assets copied');
    } catch (e) {
      print('[ModuleHttpServer:${config.id}] ❌ Error copying assets: $e');
      rethrow;
    }
  }

  /// Copy module-specific files
  Future<void> _copyModuleFiles() async {
    final filesToCopy = [
      'dist/index.html',
      'dist/bundle.js',
      'dist/bundle.js.map',
    ];

    int copiedCount = 0;
    for (final file in filesToCopy) {
      try {
        final assetPath = '${config.assetPath}/$file';
        final destPath = path.join(_tempModulePath!, file);

        // Create parent directory
        final destFile = File(destPath);
        await destFile.parent.create(recursive: true);

        // Copy file
        final data = await rootBundle.load(assetPath);
        final bytes = data.buffer.asUint8List();
        await destFile.writeAsBytes(bytes);

        copiedCount++;
      } catch (e) {
        print('[ModuleHttpServer:${config.id}] Warning: Could not copy $file: $e');
      }
    }

    print('[ModuleHttpServer:${config.id}] ✅ Copied $copiedCount files');
  }

  /// Copy shared assets (utilities, bridge helpers)
  Future<void> _copySharedAssets() async {
    try {
      final sharedDestPath = path.join(_tempModulePath!, 'shared');
      final sharedDir = Directory(sharedDestPath);
      await sharedDir.create(recursive: true);

      // Files are at root of assets/modules/shared/
      final sharedFiles = [
        'bridge_helper.js',
        'ActionQueueGlobal.js',
        'ReferenceDataManager.js',
        'SyncManager.js',
      ];

      int copiedCount = 0;
      for (final fileName in sharedFiles) {
        try {
          final assetPath = 'assets/modules/shared/$fileName';
          final destPath = path.join(sharedDestPath, fileName);

          final data = await rootBundle.load(assetPath);
          final bytes = data.buffer.asUint8List();

          final destFile = File(destPath);
          await destFile.parent.create(recursive: true);
          await destFile.writeAsBytes(bytes);

          copiedCount++;
        } catch (e) {
          print('[ModuleHttpServer:${config.id}] Warning: Could not copy shared/$fileName: $e');
        }
      }

      print('[ModuleHttpServer:${config.id}] ✅ Copied $copiedCount shared files');
    } catch (e) {
      print('[ModuleHttpServer:${config.id}] Warning: Shared assets copy failed: $e');
    }
  }

  /// Handle incoming HTTP requests
  Future<shelf.Response> _handleRequest(shelf.Request request) async {
    final requestPath = request.url.path;

    // Root path: serve index.html
    if (requestPath.isEmpty || requestPath == '/') {
      final indexPath = path.join(_tempModulePath!, 'dist', 'index.html');
      return _serveFile(indexPath, 'text/html');
    }

    // Serve specific file
    final fullPath = path.join(_tempModulePath!, requestPath);
    return _serveFile(fullPath, _getContentType(requestPath));
  }

  /// Serve a file from the filesystem
  Future<shelf.Response> _serveFile(String filePath, String contentType) async {
    try {
      final file = File(filePath);

      if (!await file.exists()) {
        return shelf.Response.notFound('File not found: $filePath');
      }

      final bytes = await file.readAsBytes();

      return shelf.Response.ok(
        bytes,
        headers: {
          'Content-Type': contentType,
          'Content-Length': bytes.length.toString(),
        },
      );
    } catch (e) {
      return shelf.Response.internalServerError(body: 'Error: $e');
    }
  }

  /// Get content type based on file extension
  String _getContentType(String filePath) {
    if (filePath.endsWith('.html')) return 'text/html; charset=utf-8';
    if (filePath.endsWith('.js')) return 'application/javascript; charset=utf-8';
    if (filePath.endsWith('.js.map')) return 'application/json';
    if (filePath.endsWith('.css')) return 'text/css; charset=utf-8';
    if (filePath.endsWith('.json')) return 'application/json';
    if (filePath.endsWith('.png')) return 'image/png';
    if (filePath.endsWith('.jpg') || filePath.endsWith('.jpeg')) return 'image/jpeg';
    if (filePath.endsWith('.svg')) return 'image/svg+xml';
    return 'application/octet-stream';
  }

  /// CORS middleware
  shelf.Middleware _corsMiddleware() {
    return shelf.createMiddleware(
      responseHandler: (shelf.Response response) {
        return response.change(headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
          'Access-Control-Allow-Headers': 'Content-Type, Authorization',
          'Access-Control-Max-Age': '86400',
        });
      },
    );
  }

  /// Logging middleware
  shelf.Middleware _loggingMiddleware() {
    return shelf.logRequests(
      logger: (message, isError) {
        if (isError) {
          print('[ModuleHttpServer:${config.id}] ❌ $message');
        }
      },
    );
  }

  /// Get server status
  Map<String, dynamic> getStatus() {
    return {
      'moduleId': config.id,
      'moduleName': config.name,
      'isRunning': _isRunning,
      'port': config.port,
      'url': baseUrl,
      'origin': origin,
      'priority': config.priority,
      'keepAlive': config.keepAlive,
    };
  }
}
