// Bridge Manager - Per-WebView communication channels
// Part of Parallel Modules Architecture
// Routes bridge calls from multiple WebViews to appropriate handlers

import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../config/modules_config.dart';
import 'shell_bridge.dart';
import 'photo_bridge_extension.dart';
import 'file_bridge_extension.dart';
import 'scanner_bridge_extension.dart';
import 'connectivity_bridge_extension.dart';

class BridgeManager {
  final Map<String, BridgeChannel> _channels = {};
  ShellBridge? _shellBridge;

  /// Singleton instance
  static final BridgeManager _instance = BridgeManager._internal();
  factory BridgeManager() => _instance;
  BridgeManager._internal();

  /// Initialize with shell bridge
  void initialize(ShellBridge shellBridge) {
    _shellBridge = shellBridge;
    print('[BridgeManager] Initialized with ShellBridge');
  }

  /// Register bridge channel for a WebView
  void registerChannel(String moduleId, WebViewController controller) {
    if (_channels.containsKey(moduleId)) {
      print('[BridgeManager] Channel already exists for $moduleId');
      return;
    }

    final channel = BridgeChannel(
      moduleId: moduleId,
      controller: controller,
      shellBridge: _shellBridge!,
    );

    _channels[moduleId] = channel;

    // Add JavaScript channel to WebView
    final channelName = 'shellBridge_$moduleId';
    controller.addJavaScriptChannel(
      channelName,
      onMessageReceived: (JavaScriptMessage message) {
        channel.handleMessage(message.message);
      },
    );

    print('[BridgeManager] ✅ Registered channel for $moduleId');
  }

  /// Unregister bridge channel
  void unregisterChannel(String moduleId) {
    _channels.remove(moduleId);
    print('[BridgeManager] Unregistered channel for $moduleId');
  }

  /// Get channel for module
  BridgeChannel? getChannel(String moduleId) {
    return _channels[moduleId];
  }

  /// Check if module has channel
  bool hasChannel(String moduleId) {
    return _channels.containsKey(moduleId);
  }

  /// Get all registered module IDs
  List<String> get registeredModules => _channels.keys.toList();

  /// Get status
  Map<String, dynamic> getStatus() {
    return {
      'totalChannels': _channels.length,
      'registeredModules': registeredModules,
    };
  }

  /// Clear all channels
  void clear() {
    _channels.clear();
    print('[BridgeManager] Cleared all channels');
  }
}

/// Bridge Channel - Per-module communication channel
class BridgeChannel {
  final String moduleId;
  final WebViewController controller;
  final ShellBridge shellBridge;

  // Extensions for this channel
  late final PhotoBridgeExtension photoExtension;
  late final FileBridgeExtension fileExtension;
  late final ScannerBridgeExtension? scannerExtension;
  late final ConnectivityBridgeExtension connectivityExtension;

  BridgeChannel({
    required this.moduleId,
    required this.controller,
    required this.shellBridge,
  }) {
    // Initialize extensions
    photoExtension = PhotoBridgeExtension();
    fileExtension = FileBridgeExtension();
    scannerExtension = ScannerBridgeExtension();
    connectivityExtension = ConnectivityBridgeExtension();

    print('[BridgeChannel:$moduleId] Channel created');
  }

  /// Handle message from JavaScript
  Future<void> handleMessage(String message) async {
    try {
      print('[BridgeChannel:$moduleId] Received message: $message');

      // Parse message
      final data = jsonDecode(message);
      final method = data['method'] as String?;
      final args = data['args'];
      final callId = data['callId'] as String?;

      if (method == null || callId == null) {
        print('[BridgeChannel:$moduleId] Invalid message format');
        return;
      }

      // Route to handler
      final result = await _routeMethod(method, args);

      // Send result back to JavaScript
      await _sendResult(callId, result);
    } catch (e) {
      print('[BridgeChannel:$moduleId] Error handling message: $e');
    }
  }

  /// Route method to appropriate handler
  Future<Map<String, dynamic>> _routeMethod(String method, dynamic args) async {
    try {
      print('[BridgeChannel:$moduleId] Routing method: $method');

      // Convert args to Map if needed
      final argsMap = args is Map ? Map<String, dynamic>.from(args) : <String, dynamic>{};

      switch (method) {
        // Photo methods
        case 'capturePhoto':
          return await photoExtension.capturePhoto(argsMap);

        // File methods
        case 'saveFile':
          return await fileExtension.saveFile(argsMap);
        case 'readFileBridge':
          return await fileExtension.readFile(argsMap);
        case 'deleteFile':
          return await fileExtension.deleteFile(argsMap);
        case 'listFiles':
          return await fileExtension.listFiles();

        // Scanner methods
        case 'scanBarcode':
          if (scannerExtension != null) {
            return await scannerExtension!.scanBarcode(argsMap);
          }
          return {'success': false, 'error': 'Scanner not available'};

        // Connectivity methods
        case 'getConnectivityStatus':
          return await connectivityExtension.getConnectivityStatus();
        case 'startConnectivityMonitoring':
          return await connectivityExtension.startMonitoring();
        case 'stopConnectivityMonitoring':
          return await connectivityExtension.stopMonitoring();

        // Other methods - delegate to ShellBridge
        default:
          // Try to handle via ShellBridge
          final methodCall = MethodCall(method, argsMap);
          final result = await shellBridge.handleMethodCall(methodCall);

          if (result is Map) {
            return Map<String, dynamic>.from(result);
          } else {
            return {'success': true, 'data': result};
          }
      }
    } catch (e) {
      print('[BridgeChannel:$moduleId] Error routing method: $e');
      return {
        'success': false,
        'error': 'Failed to execute $method: ${e.toString()}',
      };
    }
  }

  /// Send result back to JavaScript
  Future<void> _sendResult(String callId, Map<String, dynamic> result) async {
    try {
      final resultJson = jsonEncode({
        'callId': callId,
        'result': result,
      });

      // Execute JavaScript to deliver result
      final script = '''
        if (window.__bridgeCallbacks && window.__bridgeCallbacks['$callId']) {
          window.__bridgeCallbacks['$callId']($resultJson);
          delete window.__bridgeCallbacks['$callId'];
        }
      ''';

      await controller.runJavaScript(script);
      print('[BridgeChannel:$moduleId] ✅ Result sent for call: $callId');
    } catch (e) {
      print('[BridgeChannel:$moduleId] ❌ Error sending result: $e');
    }
  }

  /// Execute JavaScript in this module's WebView
  Future<void> executeJavaScript(String script) async {
    try {
      await controller.runJavaScript(script);
    } catch (e) {
      print('[BridgeChannel:$moduleId] Error executing JavaScript: $e');
    }
  }

  /// Evaluate JavaScript and get result
  Future<String?> evaluateJavaScript(String script) async {
    try {
      final result = await controller.runJavaScriptReturningResult(script);
      return result.toString();
    } catch (e) {
      print('[BridgeChannel:$moduleId] Error evaluating JavaScript: $e');
      return null;
    }
  }

  /// Notify module of an event
  Future<void> notify(String eventName, Map<String, dynamic> data) async {
    try {
      final dataJson = jsonEncode(data);
      final script = '''
        if (window.shellBridge && window.shellBridge._handleEvent) {
          window.shellBridge._handleEvent('$eventName', $dataJson);
        }
      ''';
      await executeJavaScript(script);
    } catch (e) {
      print('[BridgeChannel:$moduleId] Error notifying event: $e');
    }
  }
}
