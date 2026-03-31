// Phase 1: Local HTTP Server
// Purpose: Provide stable localhost origin for WebView to fix file:// issues
// This enables reliable IndexedDB usage in React modules

import 'dart:io';
import 'dart:async';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class LocalHttpServer {
  HttpServer? _server;
  int? _port;
  String? _baseUrl;
  bool _isRunning = false;
  String? _tempModulesPath;

  // Configuration
  static const int defaultPort = 8080;
  static const String modulesAssetPath = 'assets/modules';

  /// Returns true if server is currently running
  bool get isRunning => _isRunning;

  /// Returns the allocated port (null if not started)
  int? get port => _port;

  /// Returns the base URL (e.g., "http://localhost:8080")
  String? get baseUrl => _baseUrl;

  /// Returns the temp directory path where modules are copied
  String? get tempModulesPath => _tempModulesPath;

  /// Start the local HTTP server
  ///
  /// This will:
  /// 1. Copy module assets to a temporary accessible directory
  /// 2. Start shelf HTTP server on port 8080 (or find available port)
  /// 3. Serve modules from http://localhost:PORT/module-id/
  /// 4. Add CORS headers for backend API calls
  Future<void> start() async {
    if (_isRunning) {
      print('[LocalHttpServer] Server already running on port $_port');
      return;
    }

    try {
      print('[LocalHttpServer] Starting server...');

      // Step 1: Copy module assets to temp directory
      await _copyModuleAssetsToTemp();

      // Step 2: Create shelf handler
      final handler = const shelf.Pipeline()
          .addMiddleware(_corsMiddleware())
          .addMiddleware(_loggingMiddleware())
          .addHandler(_handleRequest);

      // Step 3: Start server
      _server = await shelf_io.serve(
        handler,
        InternetAddress.loopbackIPv4,
        defaultPort,
      );

      _port = _server!.port;
      _baseUrl = 'http://localhost:$_port';
      _isRunning = true;

      print('[LocalHttpServer] ✅ Server started successfully');
      print('[LocalHttpServer] 📍 URL: $_baseUrl');
      print('[LocalHttpServer] 📁 Modules path: $_tempModulesPath');
      print('[LocalHttpServer] 🚀 Ready to serve modules');
    } catch (e) {
      print('[LocalHttpServer] ❌ Failed to start server: $e');

      // Try alternative port if default is busy
      if (e.toString().contains('Address already in use')) {
        print('[LocalHttpServer] Port $defaultPort is busy, trying alternative port...');
        await _startOnAlternativePort();
      } else {
        rethrow;
      }
    }
  }

  /// Start server on an alternative port if default is busy
  Future<void> _startOnAlternativePort() async {
    for (int port = 8081; port <= 8090; port++) {
      try {
        final handler = const shelf.Pipeline()
            .addMiddleware(_corsMiddleware())
            .addMiddleware(_loggingMiddleware())
            .addHandler(_handleRequest);

        _server = await shelf_io.serve(
          handler,
          InternetAddress.loopbackIPv4,
          port,
        );

        _port = _server!.port;
        _baseUrl = 'http://localhost:$_port';
        _isRunning = true;

        print('[LocalHttpServer] ✅ Server started on alternative port');
        print('[LocalHttpServer] 📍 URL: $_baseUrl');
        return;
      } catch (e) {
        // Try next port
        continue;
      }
    }

    throw Exception('Could not find available port between 8080-8090');
  }

  /// Stop the server
  Future<void> stop() async {
    if (!_isRunning || _server == null) {
      print('[LocalHttpServer] Server not running, nothing to stop');
      return;
    }

    try {
      print('[LocalHttpServer] Stopping server...');
      await _server!.close(force: true);
      _server = null;
      _port = null;
      _baseUrl = null;
      _isRunning = false;
      print('[LocalHttpServer] ✅ Server stopped');
    } catch (e) {
      print('[LocalHttpServer] ❌ Error stopping server: $e');
    }
  }

  /// Pause the server (keep port allocated but don't serve)
  /// Useful when app is backgrounded
  Future<void> pause() async {
    if (!_isRunning) {
      return;
    }

    print('[LocalHttpServer] Server paused (app backgrounded)');
    // Note: We don't actually stop the server here to maintain the port
    // The server continues running but app is paused
  }

  /// Resume the server after pause
  /// Useful when app returns to foreground
  Future<void> resume() async {
    if (!_isRunning) {
      // Server was stopped, restart it
      await start();
    } else {
      print('[LocalHttpServer] Server resumed (app foregrounded)');
    }
  }

  /// Copy module assets from Flutter assets to temp directory
  /// This is necessary because shelf can't directly serve Flutter assets
  Future<void> _copyModuleAssetsToTemp() async {
    try {
      print('[LocalHttpServer] Copying module assets to temp directory...');

      // Get temp directory
      final tempDir = await getTemporaryDirectory();
      _tempModulesPath = path.join(tempDir.path, 'modules');

      // Create modules directory
      final modulesDir = Directory(_tempModulesPath!);
      if (await modulesDir.exists()) {
        print('[LocalHttpServer] Cleaning existing modules directory...');
        await modulesDir.delete(recursive: true);
      }
      await modulesDir.create(recursive: true);

      // NEW Phase 4: Copy test-inventory-checker module
      await _copyModule('test-inventory-checker');

      // NEW Phase 5: Copy test-quality-inspector module
      await _copyModule('test-quality-inspector');

      // Copy shared bridge helper
      await _copySharedAssets();

      print('[LocalHttpServer] ✅ Module assets copied successfully');
    } catch (e) {
      print('[LocalHttpServer] ❌ Error copying module assets: $e');
      rethrow;
    }
  }

  /// Copy shared assets (bridge_helper.js)
  Future<void> _copySharedAssets() async {
    try {
      print('[LocalHttpServer] Copying shared assets...');

      final sharedDestPath = path.join(_tempModulesPath!, 'shared');
      final sharedDir = Directory(sharedDestPath);
      await sharedDir.create(recursive: true);

      // List of shared files to copy
      final sharedFiles = [
        'bridge_helper.js',
        'ReferenceDataManager.js',
        'SyncManager.js',
      ];

      for (final fileName in sharedFiles) {
        try {
          final assetPath = '$modulesAssetPath/shared/$fileName';
          final destPath = path.join(sharedDestPath, fileName);

          final data = await rootBundle.load(assetPath);
          final bytes = data.buffer.asUint8List();

          final destFile = File(destPath);
          await destFile.parent.create(recursive: true);
          await destFile.writeAsBytes(bytes);

          print('[LocalHttpServer] ✅ Copied $fileName');
        } catch (e) {
          print('[LocalHttpServer] Warning: Could not copy $fileName: $e');
        }
      }
    } catch (e) {
      print('[LocalHttpServer] ❌ Error copying shared assets: $e');
    }
  }

  /// Copy a specific module from assets to temp directory
  Future<void> _copyModule(String moduleName) async {
    try {
      print('[LocalHttpServer] Copying module: $moduleName');

      final moduleDestPath = path.join(_tempModulesPath!, moduleName);
      final moduleDir = Directory(moduleDestPath);
      await moduleDir.create(recursive: true);

      // List of files to copy (in dist/ folder)
      final filesToCopy = [
        'dist/index.html',
        'dist/bundle.js',
        'dist/bundle.js.map',
      ];

      int copiedCount = 0;
      for (final file in filesToCopy) {
        try {
          final assetPath = '$modulesAssetPath/$moduleName/$file';
          final destPath = path.join(moduleDestPath, file);

          // Create parent directory
          final destFile = File(destPath);
          await destFile.parent.create(recursive: true);

          // Copy file
          final data = await rootBundle.load(assetPath);
          final bytes = data.buffer.asUint8List();
          await destFile.writeAsBytes(bytes);

          copiedCount++;
        } catch (e) {
          print('[LocalHttpServer] Warning: Could not copy $file: $e');
          // Continue with other files
        }
      }

      print('[LocalHttpServer] ✅ Copied $copiedCount files for $moduleName');
    } catch (e) {
      print('[LocalHttpServer] ❌ Error copying module $moduleName: $e');
      // Don't rethrow - allow server to start even if one module fails
    }
  }

  /// Handle incoming HTTP requests
  Future<shelf.Response> _handleRequest(shelf.Request request) async {
    final requestPath = request.url.path;

    print('[LocalHttpServer] 📨 Request: ${request.method} /$requestPath');

    // Handle root path
    if (requestPath.isEmpty || requestPath == '/') {
      return shelf.Response.ok(
        _generateIndexPage(),
        headers: {'Content-Type': 'text/html'},
      );
    }

    // Parse module path: /module-name/file or /module-name/
    final pathSegments = requestPath.split('/').where((s) => s.isNotEmpty).toList();

    if (pathSegments.isEmpty) {
      return shelf.Response.notFound('Invalid path');
    }

    final moduleName = pathSegments[0];

    // If only module name, redirect to index.html
    if (pathSegments.length == 1) {
      final indexPath = path.join(_tempModulesPath!, moduleName, 'dist', 'index.html');
      return _serveFile(indexPath, 'text/html');
    }

    // Serve specific file
    final filePath = pathSegments.skip(1).join('/');
    final fullPath = path.join(_tempModulesPath!, moduleName, filePath);

    return _serveFile(fullPath, _getContentType(filePath));
  }

  /// Serve a file from the filesystem
  Future<shelf.Response> _serveFile(String filePath, String contentType) async {
    try {
      final file = File(filePath);

      if (!await file.exists()) {
        print('[LocalHttpServer] ❌ File not found: $filePath');
        return shelf.Response.notFound('File not found: $filePath');
      }

      final bytes = await file.readAsBytes();
      print('[LocalHttpServer] ✅ Served file: $filePath (${bytes.length} bytes)');

      return shelf.Response.ok(
        bytes,
        headers: {
          'Content-Type': contentType,
          'Content-Length': bytes.length.toString(),
        },
      );
    } catch (e) {
      print('[LocalHttpServer] ❌ Error serving file: $e');
      return shelf.Response.internalServerError(body: 'Error serving file: $e');
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
    if (filePath.endsWith('.woff')) return 'font/woff';
    if (filePath.endsWith('.woff2')) return 'font/woff2';
    return 'application/octet-stream';
  }

  /// CORS middleware to allow backend API calls from WebView
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
          print('[LocalHttpServer] ❌ $message');
        } else {
          // Don't log every request to avoid spam
          // Already logging in _handleRequest
        }
      },
    );
  }

  /// Generate index page listing available modules
  String _generateIndexPage() {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Foundry Shell - Local HTTP Server</title>
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Arial, sans-serif;
      max-width: 800px;
      margin: 50px auto;
      padding: 20px;
      background: #f5f5f5;
    }
    .container {
      background: white;
      border-radius: 8px;
      padding: 30px;
      box-shadow: 0 2px 8px rgba(0,0,0,0.1);
    }
    h1 {
      color: #333;
      margin-top: 0;
    }
    .status {
      background: #4CAF50;
      color: white;
      padding: 10px 15px;
      border-radius: 4px;
      display: inline-block;
      margin-bottom: 20px;
    }
    .info {
      background: #e3f2fd;
      border-left: 4px solid #2196F3;
      padding: 15px;
      margin: 20px 0;
    }
    .modules {
      margin-top: 30px;
    }
    .module-link {
      display: block;
      padding: 15px;
      background: #fafafa;
      border: 1px solid #ddd;
      border-radius: 4px;
      margin: 10px 0;
      text-decoration: none;
      color: #2196F3;
      transition: background 0.2s;
    }
    .module-link:hover {
      background: #e3f2fd;
    }
    .badge {
      background: #667eea;
      color: white;
      padding: 2px 8px;
      border-radius: 10px;
      font-size: 11px;
      margin-left: 8px;
    }
    code {
      background: #f5f5f5;
      padding: 2px 6px;
      border-radius: 3px;
      font-family: 'Courier New', monospace;
    }
  </style>
</head>
<body>
  <div class="container">
    <h1>🚀 Foundry Shell - Local HTTP Server</h1>
    <div class="status">✅ Server Running</div>

    <div class="info">
      <strong>Server URL:</strong> <code>$_baseUrl</code><br>
      <strong>Port:</strong> <code>$_port</code><br>
      <strong>Origin:</strong> <code>http://localhost:$_port</code> (stable for IndexedDB)
    </div>

    <div class="modules">
      <h2>📦 Available Modules</h2>

      <!-- Commented out until Phase 9: Rebuild sample-warehouse module
      <a href="/sample-warehouse/" class="module-link">
        <strong>Sample Warehouse</strong><br>
        <small>Receiving transactions, water temperature checks, complaints</small>
      </a>
      -->

      <a href="/test-inventory-checker/" class="module-link">
        <strong>📊 Test: Inventory Checker</strong>
        <span class="badge">Phase 4</span><br>
        <small>Product search, stock counts, audit trail - Demonstrates hybrid architecture</small>
      </a>

      <a href="/test-quality-inspector/" class="module-link">
        <strong>🔍 Test: Quality Inspector</strong>
        <span class="badge">NEW - Phase 5</span><br>
        <small>Defect lookup, inspection logs, report submission - Validates module isolation</small>
      </a>
    </div>

    <div class="info">
      <strong>Architecture:</strong> Hybrid Storage<br>
      <strong>Source of Truth:</strong> Flutter SQLite (action_queue)<br>
      <strong>Reference Cache:</strong> IndexedDB (per module)<br>
      <strong>Phase:</strong> 4 - Test Modules ✅
    </div>
  </div>
</body>
</html>
    ''';
  }

  /// Add a module dynamically (for future phases when new modules are added)
  Future<void> addModule(String moduleName) async {
    if (!_isRunning) {
      print('[LocalHttpServer] Server not running, cannot add module');
      return;
    }

    print('[LocalHttpServer] Adding module: $moduleName');
    await _copyModule(moduleName);
    print('[LocalHttpServer] ✅ Module $moduleName added and ready to serve');
  }

  /// Remove a module
  Future<void> removeModule(String moduleName) async {
    try {
      final moduleDir = Directory(path.join(_tempModulesPath!, moduleName));
      if (await moduleDir.exists()) {
        await moduleDir.delete(recursive: true);
        print('[LocalHttpServer] ✅ Module $moduleName removed');
      }
    } catch (e) {
      print('[LocalHttpServer] ❌ Error removing module: $e');
    }
  }

  /// Get server status for debugging
  Map<String, dynamic> getStatus() {
    return {
      'isRunning': _isRunning,
      'port': _port,
      'baseUrl': _baseUrl,
      'tempModulesPath': _tempModulesPath,
    };
  }
}
