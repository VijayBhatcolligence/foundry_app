// WebView Registry - Track all WebView instances for parallel execution
// Part of Parallel Modules Architecture

import 'dart:collection';
import 'package:flutter/widgets.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../config/modules_config.dart';
import 'webview_state.dart';

/// WebView entry in registry
class WebViewEntry {
  final String moduleId;
  final WebViewController controller;
  final Widget widget;
  WebViewInfo info;

  WebViewEntry({
    required this.moduleId,
    required this.controller,
    required this.widget,
    required this.info,
  });

  /// Update state
  void updateState(WebViewState newState) {
    info = info.copyWith(state: newState);
  }

  /// Mark as accessed
  void markAccessed() {
    info = info.copyWith(
      lastAccessedAt: DateTime.now(),
      accessCount: info.accessCount + 1,
    );
  }
}

/// WebView Registry - Singleton to track all WebView instances
class WebViewRegistry {
  final Map<String, WebViewEntry> _registry = {};
  String? _currentModuleId;

  /// Singleton instance
  static final WebViewRegistry _instance = WebViewRegistry._internal();
  factory WebViewRegistry() => _instance;
  WebViewRegistry._internal();

  /// Get current visible module ID
  String? get currentModuleId => _currentModuleId;

  /// Get all registered module IDs
  List<String> get registeredModuleIds => _registry.keys.toList();

  /// Get all active WebView entries
  List<WebViewEntry> get activeEntries {
    return _registry.values
        .where((entry) => entry.info.state.isActive)
        .toList();
  }

  /// Get count of active WebViews
  int get activeCount => activeEntries.length;

  /// Register a WebView
  void register(String moduleId, WebViewController controller, Widget widget) {
    final config = ModulesRegistry.getModule(moduleId);
    if (config == null) {
      print('[WebViewRegistry] ❌ Module $moduleId not found in registry');
      return;
    }

    final info = WebViewInfo(
      moduleId: moduleId,
      moduleName: config.name,
      url: config.getUrl(),
      state: WebViewState.background,
      createdAt: DateTime.now(),
    );

    _registry[moduleId] = WebViewEntry(
      moduleId: moduleId,
      controller: controller,
      widget: widget,
      info: info,
    );

    print('[WebViewRegistry] ✅ Registered WebView for $moduleId');
    print('[WebViewRegistry]   Active WebViews: ${activeCount}/${_registry.length}');
  }

  /// Unregister a WebView
  void unregister(String moduleId) {
    final entry = _registry.remove(moduleId);
    if (entry != null) {
      entry.updateState(WebViewState.disposed);
      print('[WebViewRegistry] ✅ Unregistered WebView for $moduleId');
      print('[WebViewRegistry]   Active WebViews: ${activeCount}/${_registry.length}');
    }
  }

  /// Get WebView controller for a module
  WebViewController? getController(String moduleId) {
    return _registry[moduleId]?.controller;
  }

  /// Get WebView widget for a module
  Widget? getWidget(String moduleId) {
    return _registry[moduleId]?.widget;
  }

  /// Get WebView info
  WebViewInfo? getInfo(String moduleId) {
    return _registry[moduleId]?.info;
  }

  /// Check if module is registered
  bool isRegistered(String moduleId) {
    return _registry.containsKey(moduleId);
  }

  /// Check if module is active
  bool isActive(String moduleId) {
    final entry = _registry[moduleId];
    return entry != null && entry.info.state.isActive;
  }

  /// Update WebView state
  void updateState(String moduleId, WebViewState newState) {
    final entry = _registry[moduleId];
    if (entry != null) {
      final oldState = entry.info.state;
      entry.updateState(newState);
      print('[WebViewRegistry] State changed for $moduleId: ${oldState.displayName} → ${newState.displayName}');
    }
  }

  /// Set current visible module
  void setCurrentModule(String moduleId) {
    // Mark previous module as background
    if (_currentModuleId != null && _currentModuleId != moduleId) {
      updateState(_currentModuleId!, WebViewState.background);
    }

    // Mark new module as foreground
    _currentModuleId = moduleId;
    updateState(moduleId, WebViewState.foreground);

    // Mark as accessed
    _registry[moduleId]?.markAccessed();

    print('[WebViewRegistry] Current module: $moduleId');
  }

  /// Get all WebView info (sorted by last access)
  List<WebViewInfo> getAllInfo() {
    final entries = _registry.values.toList();
    entries.sort((a, b) {
      final aTime = a.info.lastAccessedAt ?? a.info.createdAt;
      final bTime = b.info.lastAccessedAt ?? b.info.createdAt;
      return bTime.compareTo(aTime); // Most recent first
    });
    return entries.map((e) => e.info).toList();
  }

  /// Get least recently used module IDs (for LRU eviction)
  List<String> getLeastRecentlyUsed({int limit = 10}) {
    final entries = _registry.values.toList();
    entries.sort((a, b) {
      final aTime = a.info.lastAccessedAt ?? a.info.createdAt;
      final bTime = b.info.lastAccessedAt ?? b.info.createdAt;
      return aTime.compareTo(bTime); // Least recent first
    });

    return entries.take(limit).map((e) => e.moduleId).toList();
  }

  /// Get modules sorted by priority (for keep-alive)
  List<String> getByPriority() {
    final entries = _registry.values.toList();
    entries.sort((a, b) {
      final configA = ModulesRegistry.getModule(a.moduleId);
      final configB = ModulesRegistry.getModule(b.moduleId);
      if (configA == null || configB == null) return 0;
      return configA.priority.compareTo(configB.priority);
    });
    return entries.map((e) => e.moduleId).toList();
  }

  /// Check if should evict (over limit)
  bool shouldEvict() {
    return activeCount > ModulesRegistry.maxConcurrentModules;
  }

  /// Get module to evict (LRU, excluding keep-alive and current)
  String? getModuleToEvict() {
    final lru = getLeastRecentlyUsed();

    for (final moduleId in lru) {
      // Don't evict current module
      if (moduleId == _currentModuleId) continue;

      // Don't evict keep-alive modules
      final config = ModulesRegistry.getModule(moduleId);
      if (config != null && config.keepAlive) continue;

      return moduleId;
    }

    return null;
  }

  /// Print status
  void printStatus() {
    print('\n[WebViewRegistry] === Status ===');
    print('[WebViewRegistry] Total registered: ${_registry.length}');
    print('[WebViewRegistry] Active: $activeCount');
    print('[WebViewRegistry] Current: $_currentModuleId');
    print('[WebViewRegistry]');

    final infos = getAllInfo();
    for (final info in infos) {
      final isCurrent = info.moduleId == _currentModuleId;
      final marker = isCurrent ? '👉' : '  ';
      print('[WebViewRegistry] $marker ${info.state.emoji} ${info.moduleName}');
      print('[WebViewRegistry]       State: ${info.state.displayName}');
      print('[WebViewRegistry]       Access count: ${info.accessCount}');
      if (info.lastAccessedAt != null) {
        print('[WebViewRegistry]       Last accessed: ${info.lastAccessedAt}');
      }
    }
  }

  /// Clear all entries
  void clear() {
    _registry.clear();
    _currentModuleId = null;
    print('[WebViewRegistry] ✅ Cleared all entries');
  }

  /// Get registry status
  Map<String, dynamic> getStatus() {
    return {
      'totalRegistered': _registry.length,
      'activeCount': activeCount,
      'currentModuleId': _currentModuleId,
      'modules': getAllInfo().map((i) => i.toJson()).toList(),
    };
  }
}
