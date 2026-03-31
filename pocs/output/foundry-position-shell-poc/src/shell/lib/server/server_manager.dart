// Server Manager - Manages multiple HTTP servers for parallel module execution
// Part of Parallel Modules Architecture

import 'dart:async';
import '../config/modules_config.dart';
import 'module_http_server.dart';

class ServerManager {
  final Map<String, ModuleHttpServer> _servers = {};
  bool _isInitialized = false;

  /// Singleton instance
  static final ServerManager _instance = ServerManager._internal();
  factory ServerManager() => _instance;
  ServerManager._internal();

  /// Check if manager is initialized
  bool get isInitialized => _isInitialized;

  /// Get all running servers
  List<ModuleHttpServer> get runningServers {
    return _servers.values.where((s) => s.isRunning).toList();
  }

  /// Get all module IDs with running servers
  List<String> get runningModuleIds {
    return _servers.entries
        .where((e) => e.value.isRunning)
        .map((e) => e.key)
        .toList();
  }

  /// Initialize and start all servers
  Future<void> startAll() async {
    if (_isInitialized) {
      print('[ServerManager] Already initialized');
      return;
    }

    print('[ServerManager] Starting all module servers...');
    print('[ServerManager] Modules to start: ${ModulesRegistry.modules.length}');

    final futures = <Future>[];

    // Create and start server for each module
    for (final config in ModulesRegistry.modules) {
      print('[ServerManager] Initializing server for ${config.id} on port ${config.port}');

      final server = ModuleHttpServer(config);
      _servers[config.id] = server;

      // Start server
      futures.add(server.start().catchError((e) {
        print('[ServerManager] ❌ Failed to start ${config.id}: $e');
        // Continue with other servers even if one fails
      }));
    }

    // Wait for all servers to start
    await Future.wait(futures);

    _isInitialized = true;

    // Print summary
    final runningCount = runningServers.length;
    final totalCount = ModulesRegistry.modules.length;

    print('[ServerManager] ✅ Started $runningCount/$totalCount servers');
    print('[ServerManager] 🚀 Parallel architecture ready!');

    // Print status for each module
    for (final config in ModulesRegistry.modules) {
      final server = _servers[config.id];
      if (server != null && server.isRunning) {
        print('[ServerManager]   ✅ ${config.iconEmoji} ${config.name}: ${config.getUrl()}');
      } else {
        print('[ServerManager]   ❌ ${config.iconEmoji} ${config.name}: Failed to start');
      }
    }
  }

  /// Start a specific module server
  Future<void> startModule(String moduleId) async {
    final server = _servers[moduleId];

    if (server != null) {
      if (server.isRunning) {
        print('[ServerManager] Server for $moduleId already running');
        return;
      }
      await server.start();
    } else {
      // Create new server for this module
      final config = ModulesRegistry.getModule(moduleId);
      if (config == null) {
        print('[ServerManager] ❌ Module $moduleId not found in registry');
        return;
      }

      print('[ServerManager] Creating server for $moduleId');
      final newServer = ModuleHttpServer(config);
      _servers[moduleId] = newServer;
      await newServer.start();
    }
  }

  /// Stop a specific module server
  Future<void> stopModule(String moduleId) async {
    final server = _servers[moduleId];
    if (server != null && server.isRunning) {
      await server.stop();
      print('[ServerManager] ✅ Stopped server for $moduleId');
    }
  }

  /// Stop all servers
  Future<void> stopAll() async {
    print('[ServerManager] Stopping all servers...');

    final futures = <Future>[];
    for (final server in _servers.values) {
      if (server.isRunning) {
        futures.add(server.stop());
      }
    }

    await Future.wait(futures);

    _isInitialized = false;
    print('[ServerManager] ✅ All servers stopped');
  }

  /// Restart a module server
  Future<void> restartModule(String moduleId) async {
    print('[ServerManager] Restarting server for $moduleId...');
    await stopModule(moduleId);
    await Future.delayed(const Duration(milliseconds: 500));
    await startModule(moduleId);
  }

  /// Restart all servers
  Future<void> restartAll() async {
    print('[ServerManager] Restarting all servers...');
    await stopAll();
    await Future.delayed(const Duration(milliseconds: 500));
    await startAll();
  }

  /// Get server for a module
  ModuleHttpServer? getServer(String moduleId) {
    return _servers[moduleId];
  }

  /// Check if module server is running
  bool isModuleRunning(String moduleId) {
    final server = _servers[moduleId];
    return server != null && server.isRunning;
  }

  /// Get URL for a module
  String? getModuleUrl(String moduleId) {
    final server = _servers[moduleId];
    return server?.baseUrl;
  }

  /// Get origin for a module (for IndexedDB)
  String? getModuleOrigin(String moduleId) {
    final server = _servers[moduleId];
    return server?.origin;
  }

  /// Get all server statuses
  List<Map<String, dynamic>> getAllStatuses() {
    return _servers.values.map((s) => s.getStatus()).toList();
  }

  /// Get overall status
  Map<String, dynamic> getStatus() {
    return {
      'isInitialized': _isInitialized,
      'totalModules': ModulesRegistry.modules.length,
      'runningServers': runningServers.length,
      'modules': getAllStatuses(),
    };
  }

  /// Print status summary
  void printStatus() {
    print('\n[ServerManager] === Status Summary ===');
    print('[ServerManager] Initialized: $_isInitialized');
    print('[ServerManager] Total modules: ${ModulesRegistry.modules.length}');
    print('[ServerManager] Running servers: ${runningServers.length}');
    print('[ServerManager]');

    for (final config in ModulesRegistry.modules) {
      final server = _servers[config.id];
      final status = server != null && server.isRunning ? '✅ RUNNING' : '❌ STOPPED';
      final url = server != null && server.isRunning ? server.baseUrl : 'N/A';

      print('[ServerManager] ${config.iconEmoji} ${config.name}');
      print('[ServerManager]   Status: $status');
      print('[ServerManager]   URL: $url');
      print('[ServerManager]   Priority: ${config.priority} ${config.keepAlive ? "(Keep Alive)" : ""}');
      print('[ServerManager]');
    }
  }

  /// Cleanup on app shutdown
  Future<void> dispose() async {
    print('[ServerManager] Disposing...');
    await stopAll();
    _servers.clear();
  }
}
