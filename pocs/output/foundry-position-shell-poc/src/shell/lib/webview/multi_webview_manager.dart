// Multi-WebView Manager - Core parallel execution engine
// Part of Parallel Modules Architecture
// Manages multiple WebView instances for true parallel module execution

import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../config/modules_config.dart';
import '../server/server_manager.dart';
import '../bridge/shell_bridge.dart';
import 'webview_state.dart';
import 'webview_registry.dart';

class MultiWebViewManager {
  final WebViewRegistry _registry = WebViewRegistry();
  final ServerManager _serverManager = ServerManager();

  /// Singleton instance
  static final MultiWebViewManager _instance = MultiWebViewManager._internal();
  factory MultiWebViewManager() => _instance;
  MultiWebViewManager._internal();

  /// ShellBridge instance for routing bridge calls
  ShellBridge? _shellBridge;

  /// Register ShellBridge for handling bridge calls from all WebViews
  void registerShellBridge(ShellBridge bridge) {
    _shellBridge = bridge;
    print('[MultiWebViewManager] ✅ ShellBridge registered for all WebViews');
  }

  /// Get registry instance
  WebViewRegistry get registry => _registry;

  /// Create WebView for a module (lazy loading)
  Future<Widget> createWebView(String moduleId) async {
    print('[MultiWebViewManager] Creating WebView for $moduleId...');

    // Check if already exists
    if (_registry.isRegistered(moduleId)) {
      print('[MultiWebViewManager] WebView already exists for $moduleId');
      final widget = _registry.getWidget(moduleId);
      if (widget != null) return widget;
    }

    // Get module config
    final config = ModulesRegistry.getModule(moduleId);
    if (config == null) {
      throw Exception('Module $moduleId not found in registry');
    }

    // Ensure server is running
    if (!_serverManager.isModuleRunning(moduleId)) {
      print('[MultiWebViewManager] Starting server for $moduleId...');
      await _serverManager.startModule(moduleId);
    }

    // Get module URL
    final url = _serverManager.getModuleUrl(moduleId);
    if (url == null) {
      throw Exception('Could not get URL for module $moduleId');
    }

    print('[MultiWebViewManager] Module URL: $url');
    print('[MultiWebViewManager] Origin: ${config.getOrigin()} (isolated IndexedDB)');

    // Create WebView controller
    final controller = WebViewController();

    // Add ONE global JavaScript channel (BEFORE page loads!)
    controller.addJavaScriptChannel(
      'shellBridge',  // ONE global channel for ALL modules
      onMessageReceived: (JavaScriptMessage message) {
        print('[MultiWebViewManager:$moduleId] Bridge message received');
        _handleBridgeMessage(moduleId, message);
      },
    );

    // Configure controller
    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFFFFFFF))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            print('[MultiWebViewManager:$moduleId] Page started: $url');
            // Bridge wrapper is in HTML - no injection needed!
          },
          onPageFinished: (String url) {
            print('[MultiWebViewManager:$moduleId] ✅ Page loaded');
            // Bridge wrapper already available from HTML
          },
          onWebResourceError: (WebResourceError error) {
            print('[MultiWebViewManager:$moduleId] ❌ Error: ${error.description}');
          },
        ),
      )
      ..loadRequest(Uri.parse(url));

    // Note: JavaScript channel already added earlier (before configuration)
    // This ensures the native channel exists when page loads

    // Create WebView widget
    final webViewWidget = WebViewWidget(controller: controller);

    // Register in registry
    _registry.register(moduleId, controller, webViewWidget);
    _registry.updateState(moduleId, WebViewState.loading);

    print('[MultiWebViewManager] ✅ WebView created for $moduleId');

    // Check if should evict old WebViews (LRU)
    await _checkAndEvict();

    return webViewWidget;
  }

  /// Inject ONE global bridge into WebView (same script for all modules)
  Future<void> _injectGlobalBridge(WebViewController controller, String moduleId) async {
    print('[MultiWebViewManager:$moduleId] Injecting ONE global bridge...');

    final bridgeScript = _getGlobalBridgeScript();

    try {
      await controller.runJavaScript(bridgeScript);
      print('[MultiWebViewManager:$moduleId] ✅ Global bridge injected successfully');
    } catch (e) {
      print('[MultiWebViewManager:$moduleId] ❌ Bridge injection failed: $e');
    }
  }

  /// Get global bridge JavaScript (SAME for all modules)
  String _getGlobalBridgeScript() {
    return '''
      (function() {
        console.log('[Bridge] Injecting ONE global bridge');

        // CRITICAL: Save reference to native Flutter channel BEFORE overwriting
        const nativeChannel = window.shellBridge;

        // Create ONE global bridge object
        window.shellBridge = {
          _call: function(method, args) {
            return new Promise((resolve, reject) => {
              try {
                const callId = Date.now() + '_' + Math.random();
                const message = JSON.stringify({
                  callId: callId,
                  method: method,
                  args: args || {}
                });

                // Store callback for response
                window.shellBridge._callbacks = window.shellBridge._callbacks || {};
                window.shellBridge._callbacks[callId] = { resolve, reject };

                // Call Flutter via saved native channel reference
                nativeChannel.postMessage(message);
              } catch (e) {
                reject(e);
              }
            });
          },

          capturePhoto: function(args) {
            console.log('[Bridge] capturePhoto called');
            return this._call('capturePhoto', args);
          },

          saveFile: function(args) {
            console.log('[Bridge] saveFile called');
            return this._call('saveFile', args);
          },

          readFileBridge: function(args) {
            console.log('[Bridge] readFileBridge called');
            return this._call('readFileBridge', args);
          },

          deleteFile: function(args) {
            console.log('[Bridge] deleteFile called');
            return this._call('deleteFile', args);
          },

          scanBarcode: function(args) {
            console.log('[Bridge] scanBarcode called');
            return this._call('scanBarcode', args);
          },

          scanQRCode: function(args) {
            console.log('[Bridge] scanQRCode called');
            return this._call('scanQRCode', args);
          },

          getNetworkState: function(args) {
            console.log('[Bridge] getNetworkState called');
            return this._call('getNetworkState', args);
          }
        };

        console.log('[Bridge] ✅ ONE global bridge ready');

        // Emit ready event
        window.dispatchEvent(new CustomEvent('shellBridgeReady', {
          detail: { global: true }
        }));
      })();
    ''';
  }

  /// Handle bridge messages from WebView (routes to ShellBridge)
  void _handleBridgeMessage(String moduleId, JavaScriptMessage message) async {
    print('[MultiWebViewManager:$moduleId] Handling bridge call...');
    print('[MultiWebViewManager:$moduleId] Raw message: ${message.message}');
    print('[MultiWebViewManager:$moduleId] Message type: ${message.message.runtimeType}');

    try {
      // Parse incoming message
      final decoded = json.decode(message.message);
      print('[MultiWebViewManager:$moduleId] Decoded: $decoded');
      print('[MultiWebViewManager:$moduleId] Decoded type: ${decoded.runtimeType}');

      final data = decoded as Map<String, dynamic>;

      final callId = data['callId'] as String;
      final method = data['method'] as String;

      // Handle args: can be Map, String, or null
      final rawArgs = data['args'];
      print('[MultiWebViewManager:$moduleId] Raw args: $rawArgs');
      print('[MultiWebViewManager:$moduleId] Raw args type: ${rawArgs.runtimeType}');

      Map<String, dynamic>? args;
      if (rawArgs is Map<String, dynamic>) {
        args = rawArgs;
      } else if (rawArgs is String) {
        // If args is a string, wrap it in a map
        args = {'value': rawArgs};
        print('[MultiWebViewManager:$moduleId] ⚠️ Args was String, wrapped: $args');
      } else if (rawArgs != null) {
        // If args is some other type, wrap it
        args = {'value': rawArgs};
        print('[MultiWebViewManager:$moduleId] ⚠️ Args was ${rawArgs.runtimeType}, wrapped: $args');
      } else {
        args = null;
      }

      print('[MultiWebViewManager:$moduleId] Bridge call: $method, callId: $callId');

      // Check if ShellBridge is registered
      if (_shellBridge == null) {
        print('[MultiWebViewManager:$moduleId] ❌ ShellBridge not registered!');
        await _sendBridgeResponse(moduleId, callId, {
          'success': false,
          'error': 'Bridge not initialized'
        });
        return;
      }

      // Route to ShellBridge.handleMethodCall()
      try {
        final methodCall = MethodCall(method, args);
        final result = await _shellBridge!.handleMethodCall(methodCall);

        print('[MultiWebViewManager:$moduleId] Bridge call SUCCESS: $method');

        // Send response back to WebView
        await _sendBridgeResponse(moduleId, callId, result);
      } catch (e) {
        print('[MultiWebViewManager:$moduleId] ❌ Bridge call error: $e');
        await _sendBridgeResponse(moduleId, callId, {
          'success': false,
          'error': e.toString()
        });
      }
    } catch (e) {
      print('[MultiWebViewManager:$moduleId] ❌ Message parsing error: $e');
    }
  }

  /// Send bridge response back to WebView
  Future<void> _sendBridgeResponse(
    String moduleId,
    String callId,
    Map<String, dynamic> result,
  ) async {
    final controller = _registry.getController(moduleId);
    if (controller == null) {
      print('[MultiWebViewManager:$moduleId] ⚠️ Controller not found for response');
      return;
    }

    try {
      final responseScript = '''
        if (window.shellBridge && window.shellBridge._callbacks) {
          const callback = window.shellBridge._callbacks['$callId'];
          if (callback) {
            callback.resolve(${json.encode(result)});
            delete window.shellBridge._callbacks['$callId'];
          }
        }
      ''';

      await controller.runJavaScript(responseScript);
      print('[MultiWebViewManager:$moduleId] ✅ Response sent: $callId');
    } catch (e) {
      print('[MultiWebViewManager:$moduleId] ❌ Failed to send response: $e');
    }
  }

  /// Get or create WebView for a module
  Future<Widget> getOrCreateWebView(String moduleId) async {
    if (_registry.isRegistered(moduleId)) {
      print('[MultiWebViewManager] Using existing WebView for $moduleId');
      final widget = _registry.getWidget(moduleId);
      if (widget != null) return widget;
    }

    return await createWebView(moduleId);
  }

  /// Switch to a module (make it visible)
  void switchToModule(String moduleId) {
    print('[MultiWebViewManager] Switching to module: $moduleId');

    if (!_registry.isRegistered(moduleId)) {
      print('[MultiWebViewManager] ⚠️ WebView not created yet for $moduleId');
      return;
    }

    // Update registry (handles foreground/background state)
    _registry.setCurrentModule(moduleId);

    print('[MultiWebViewManager] ✅ Now showing: $moduleId');
  }

  /// Dispose a WebView (destroy and remove from memory)
  Future<void> disposeWebView(String moduleId) async {
    print('[MultiWebViewManager] Disposing WebView for $moduleId...');

    if (!_registry.isRegistered(moduleId)) {
      print('[MultiWebViewManager] WebView not found for $moduleId');
      return;
    }

    // Don't dispose current module
    if (_registry.currentModuleId == moduleId) {
      print('[MultiWebViewManager] ⚠️ Cannot dispose current module');
      return;
    }

    // Don't dispose keep-alive modules
    final config = ModulesRegistry.getModule(moduleId);
    if (config != null && config.keepAlive) {
      print('[MultiWebViewManager] ⚠️ Cannot dispose keep-alive module');
      return;
    }

    // Unregister
    _registry.unregister(moduleId);

    print('[MultiWebViewManager] ✅ WebView disposed for $moduleId');
  }

  /// Check if should evict and evict least recently used
  Future<void> _checkAndEvict() async {
    if (!_registry.shouldEvict()) {
      return;
    }

    print('[MultiWebViewManager] Active WebViews (${_registry.activeCount}) exceeds limit (${ModulesRegistry.maxConcurrentModules})');
    print('[MultiWebViewManager] Performing LRU eviction...');

    final moduleToEvict = _registry.getModuleToEvict();
    if (moduleToEvict != null) {
      print('[MultiWebViewManager] Evicting: $moduleToEvict');
      await disposeWebView(moduleToEvict);
    } else {
      print('[MultiWebViewManager] ⚠️ No modules available for eviction (all are keep-alive or current)');
    }
  }

  /// Pause a WebView (optional optimization)
  void pauseWebView(String moduleId) {
    if (_registry.isRegistered(moduleId)) {
      _registry.updateState(moduleId, WebViewState.paused);
      print('[MultiWebViewManager] ⏸️ Paused WebView for $moduleId');
      // Note: Actual JavaScript pause would require evaluateJavaScript calls
    }
  }

  /// Resume a WebView
  void resumeWebView(String moduleId) {
    if (_registry.isRegistered(moduleId)) {
      _registry.updateState(moduleId, WebViewState.background);
      print('[MultiWebViewManager] ▶️ Resumed WebView for $moduleId');
    }
  }

  /// Reload a WebView
  Future<void> reloadWebView(String moduleId) async {
    final controller = _registry.getController(moduleId);
    if (controller != null) {
      print('[MultiWebViewManager] 🔄 Reloading WebView for $moduleId');
      await controller.reload();
    }
  }

  /// Evaluate JavaScript in a WebView
  Future<String?> evaluateJavaScript(String moduleId, String script) async {
    final controller = _registry.getController(moduleId);
    if (controller != null) {
      try {
        final result = await controller.runJavaScriptReturningResult(script);
        return result.toString();
      } catch (e) {
        print('[MultiWebViewManager] ❌ JavaScript evaluation error: $e');
        return null;
      }
    }
    return null;
  }

  /// Execute JavaScript in a WebView (no return value)
  Future<void> executeJavaScript(String moduleId, String script) async {
    final controller = _registry.getController(moduleId);
    if (controller != null) {
      try {
        await controller.runJavaScript(script);
      } catch (e) {
        print('[MultiWebViewManager] ❌ JavaScript execution error: $e');
      }
    }
  }

  /// Get current module ID
  String? get currentModuleId => _registry.currentModuleId;

  /// Get all active module IDs
  List<String> get activeModuleIds => _registry.registeredModuleIds;

  /// Check if module is loaded
  bool isModuleLoaded(String moduleId) {
    return _registry.isRegistered(moduleId);
  }

  /// Check if module is current (visible)
  bool isModuleCurrent(String moduleId) {
    return _registry.currentModuleId == moduleId;
  }

  /// Get module state
  WebViewState? getModuleState(String moduleId) {
    return _registry.getInfo(moduleId)?.state;
  }

  /// Print status
  void printStatus() {
    print('\n[MultiWebViewManager] === Manager Status ===');
    print('[MultiWebViewManager] Active modules: ${_registry.activeCount}/${ModulesRegistry.maxConcurrentModules}');
    print('[MultiWebViewManager] Current: ${_registry.currentModuleId}');
    print('[MultiWebViewManager]');
    _registry.printStatus();
  }

  /// Get status
  Map<String, dynamic> getStatus() {
    return {
      'activeCount': _registry.activeCount,
      'maxConcurrent': ModulesRegistry.maxConcurrentModules,
      'currentModuleId': _registry.currentModuleId,
      'registry': _registry.getStatus(),
    };
  }

  /// Dispose all WebViews
  Future<void> disposeAll() async {
    print('[MultiWebViewManager] Disposing all WebViews...');

    final moduleIds = List<String>.from(_registry.registeredModuleIds);
    for (final moduleId in moduleIds) {
      // Skip keep-alive modules
      final config = ModulesRegistry.getModule(moduleId);
      if (config != null && config.keepAlive) continue;

      await disposeWebView(moduleId);
    }

    print('[MultiWebViewManager] ✅ All disposable WebViews disposed');
  }

  /// Cleanup on app shutdown
  Future<void> dispose() async {
    print('[MultiWebViewManager] Disposing manager...');
    _registry.clear();
  }
}
