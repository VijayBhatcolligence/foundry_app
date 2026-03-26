import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Connectivity Bridge Extension
///
/// Monitors device connectivity and injects JavaScript events into WebView
/// to notify React when network state changes.
///
/// This is the ONLY Flutter-side responsibility for offline functionality.
/// All data storage and sync logic lives in React/JavaScript.
class ConnectivityBridgeExtension {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  WebViewController? _webViewController;
  bool _isOnline = true;

  /// Initialize connectivity monitoring
  void initialize(WebViewController webViewController) {
    _webViewController = webViewController;

    print('[ConnectivityBridge] Initializing connectivity monitoring');

    // Get initial connectivity state
    _checkInitialConnectivity();

    // Listen for connectivity changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _onConnectivityChanged,
      onError: (error) {
        print('[ConnectivityBridge] Error: $error');
      },
    );

    print('[ConnectivityBridge] Connectivity monitoring started');
  }

  /// Check initial connectivity state
  Future<void> _checkInitialConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _onConnectivityChanged(result);
    } catch (error) {
      print('[ConnectivityBridge] Failed to check initial connectivity: $error');
    }
  }

  /// Handle connectivity changes
  void _onConnectivityChanged(ConnectivityResult result) {
    // Determine if online (any non-none connection)
    final isOnline = result != ConnectivityResult.none;

    print('[ConnectivityBridge] Connectivity changed: $result (online: $isOnline)');

    // Only notify if state actually changed
    if (_isOnline != isOnline) {
      _isOnline = isOnline;
      _notifyWebView(isOnline);
    }
  }

  /// Inject connectivity event into WebView
  void _notifyWebView(bool isOnline) {
    if (_webViewController == null) {
      print('[ConnectivityBridge] WebView controller not set');
      return;
    }

    final event = {
      'online': isOnline,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    final jsonEvent = jsonEncode(event);

    // Inject JavaScript to fire window.onConnectivityChange event
    final script = '''
      (function() {
        console.log('[Flutter] Connectivity change:', $jsonEvent);

        if (typeof window.onConnectivityChange === 'function') {
          window.onConnectivityChange($jsonEvent);
        } else {
          console.warn('[Flutter] window.onConnectivityChange not defined');
        }

        // Also dispatch a custom DOM event for React to listen to
        const event = new CustomEvent('flutterConnectivityChange', {
          detail: $jsonEvent
        });
        window.dispatchEvent(event);
      })();
    ''';

    _webViewController!.runJavaScript(script);

    print('[ConnectivityBridge] Event injected: ${isOnline ? "ONLINE" : "OFFLINE"}');
  }

  /// Get current network state
  Future<Map<String, dynamic>> getNetworkState() async {
    try {
      final result = await _connectivity.checkConnectivity();
      final isOnline = result != ConnectivityResult.none;

      return {
        'online': isOnline,
        'connectionType': result.toString(),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
    } catch (error) {
      print('[ConnectivityBridge] Failed to get network state: $error');
      return {
        'online': false,
        'error': error.toString(),
      };
    }
  }

  /// Clean up resources
  void dispose() {
    print('[ConnectivityBridge] Disposing connectivity subscription');
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    _webViewController = null;
  }
}
