import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import 'auth/mock_auth_service.dart';
import 'position/position_resolver.dart';
import 'session/session_broker.dart';
import 'bridge/shell_bridge.dart';
import 'modules/module_registry.dart';
import 'modules/module_cache.dart';
import 'modules/module_updater.dart';
import 'modules/fallback_manager.dart';
import 'security/module_verifier.dart';
import 'bridge/module_bridge_extension.dart';
import 'bridge/scanner_bridge_extension.dart';
import 'bridge/photo_bridge_extension.dart';
import 'demo/crypto_verification_demo.dart';
import 'network/network_monitor.dart';
import 'offline/offline_transaction_queue.dart';
import 'offline/sync_manager.dart';
import 'modules/update_scheduler.dart';
import 'ui/module_selection_screen.dart';

void main() {
  runApp(const FoundryShellApp());
}

class FoundryShellApp extends StatelessWidget {
  const FoundryShellApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Foundry Shell',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const ShellHomePage(),
    );
  }
}

class ShellHomePage extends StatefulWidget {
  const ShellHomePage({Key? key}) : super(key: key);

  @override
  State<ShellHomePage> createState() => _ShellHomePageState();
}

class _ShellHomePageState extends State<ShellHomePage> {
  // Phase 1 Services
  late final MockAuthService _authService;
  late final PositionResolver _positionResolver;
  late final SessionBroker _sessionBroker;
  late ShellBridge _shellBridge;
  late MethodChannel _methodChannel; // Store MethodChannel to reuse in bridge handler

  // Phase 2 Services
  late final ModuleRegistry _moduleRegistry;
  late final ModuleCache _moduleCache;
  late final ModuleVerifier _moduleVerifier;
  late final FallbackManager _fallbackManager;
  late final ModuleUpdater _moduleUpdater;
  late final ModuleBridgeExtension _moduleBridgeExtension;

  // Phase 5 Services
  late final ScannerBridgeExtension _scannerBridgeExtension;

  // Phase 5.1 Services
  late final PhotoBridgeExtension _photoBridgeExtension;

  // WebView controller
  late final WebViewController _webViewController;

  // State
  bool _isAuthenticated = false;
  bool _isLoading = false;
  bool _servicesInitialized = false;
  Position? _currentPosition;
  String _statusMessage = 'Initializing services...';

  // Phase 3.5: Module selection state
  bool _showModuleSelection = false;
  String? _selectedModuleId;

  // Text controllers for login
  final _usernameController = TextEditingController(text: 'demo_user');
  final _passwordController = TextEditingController(text: 'password');

  @override
  void initState() {
    super.initState();
    _initializeWebView();
    _initializeServicesAsync();
  }

  /// Initializes core services asynchronously
  Future<void> _initializeServicesAsync() async {
    try {
      // Phase 1 services
      _authService = MockAuthService();
      _positionResolver = PositionResolver();
      _sessionBroker = SessionBroker();

      // Phase 2 services
      print('[Phase 2] Initializing module management services...');

      _moduleRegistry = ModuleRegistry.instance;
      _moduleCache = ModuleCache.instance;
      _moduleVerifier = ModuleVerifier();
      _fallbackManager = FallbackManager.instance;
      _moduleUpdater = ModuleUpdater.instance;

      // Load module registry (POC mode - mock registry)
      print('[ModuleRegistry] Loading registry...');
      final registryResult = await _moduleRegistry.loadRegistry('mock://registry.json');
      if (registryResult.success) {
        print('[ModuleRegistry] Registry loaded successfully: ${registryResult.modulesLoaded} modules');
      } else {
        print('[ModuleRegistry] Warning: Registry load failed: ${registryResult.error}');
      }

      // Initialize Phase 1 bridge
      // CRITICAL: Store MethodChannel as instance variable so we reuse the SAME instance
      // Creating multiple MethodChannel instances with same name doesn't share handlers!
      print('[Main] Creating MethodChannel: com.foundry.shell/bridge');
      _methodChannel = const MethodChannel('com.foundry.shell/bridge');

      print('[Main] Initializing ShellBridge...');
      _shellBridge = ShellBridge(
        channel: _methodChannel,
        authService: _authService,
        positionResolver: _positionResolver,
        sessionBroker: _sessionBroker,
      );
      print('[Main] ShellBridge initialized with handler registered');

      // Register Phase 2 module bridge extension
      print('[ModuleBridge] Registering module management methods...');
      _moduleBridgeExtension = ModuleBridgeExtension();
      _moduleBridgeExtension.registerWithBridge(_shellBridge);

      print('[Phase 2] Integration complete - Module management active');

      // Phase 5: Register scanner bridge extension
      print('[ScannerBridge] ========================================');
      print('[ScannerBridge] Registering scanner methods...');
      _scannerBridgeExtension = ScannerBridgeExtension();
      print('[ScannerBridge] Extension created: ${_scannerBridgeExtension.hashCode}');

      _scannerBridgeExtension.registerWithBridge(_shellBridge);
      print('[ScannerBridge] registerWithBridge() called');

      _shellBridge.registerScannerExtension(_scannerBridgeExtension);
      print('[ScannerBridge] registerScannerExtension() called');

      print('[Phase 5] ✅ Scanner integration complete - Scanner methods registered');
      print('[ScannerBridge] ========================================');

      // Phase 5.1: Register photo bridge extension
      print('[PhotoBridge] Registering photo methods...');
      _photoBridgeExtension = PhotoBridgeExtension();
      _photoBridgeExtension.registerWithBridge(_shellBridge);
      _shellBridge.registerPhotoExtension(_photoBridgeExtension);
      print('[Phase 5.1] Photo integration complete - Photo methods registered');

      // Phase 3 services - Offline & Critical Workflow
      print('[Phase 3] Initializing offline and network services...');

      // Initialize network monitor
      final networkMonitor = NetworkMonitor.instance;
      await networkMonitor.initialize();
      print('[Phase 3] Network monitor initialized');

      // Offline queue auto-initializes on first access
      print('[Phase 3] Offline queue ready');

      // Initialize sync manager
      final syncManager = SyncManager.instance;
      await syncManager.initialize();
      print('[Phase 3] Sync manager initialized');

      // Initialize update scheduler
      final updateScheduler = UpdateScheduler.instance;
      await updateScheduler.start();
      print('[Phase 3] Update scheduler started');

      // Check current network state
      final networkState = networkMonitor.currentState;
      final isOnline = await networkMonitor.isOnline();
      print('[Network] Current state: ${networkState.name.toUpperCase()}');
      print('[Network] Internet reachability: $isOnline');

      // Trigger initial sync to download transactions from backend
      if (isOnline) {
        print('[Phase 3] Triggering initial sync to fetch backend data...');
        syncManager.syncNow().then((result) {
          print('[Phase 3] Initial sync complete: ${result.downloadedCount} downloaded, ${result.syncedCount} uploaded');
        }).catchError((error) {
          print('[Phase 3] Initial sync error: $error');
        });
      } else {
        print('[Phase 3] Offline - skipping initial sync');
      }

      print('[Phase 3] Integration complete - Offline features active');

      // Run crypto verification demo to show native crypto is working
      print('[Demo] Running signature verification demo...');
      await _runCryptoDemo();

      setState(() {
        _servicesInitialized = true;
        _statusMessage = 'Ready to authenticate';
      });
    } catch (e) {
      print('[ERROR] Service initialization failed: $e');
      setState(() {
        _statusMessage = 'Service initialization failed: $e';
      });
    }
  }

  /// Run crypto verification demo to show native crypto is working
  Future<void> _runCryptoDemo() async {
    try {
      await CryptoVerificationDemo.run();
    } catch (e) {
      print('[Demo] Error running crypto demo: $e');
    }
  }

  /// Initializes WebView with platform-specific settings
  void _initializeWebView() {
    // Platform-specific WebView parameters
    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    _webViewController = WebViewController.fromPlatformCreationParams(params);

    // Configure WebView
    _webViewController
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            debugPrint('Page started loading: $url');
          },
          onPageFinished: (String url) async {
            debugPrint('Page finished loading: $url');

            // Wait for services to initialize before injecting bridge
            while (!_servicesInitialized) {
              debugPrint('[Bridge] Waiting for services to initialize...');
              await Future.delayed(const Duration(milliseconds: 100));
            }

            debugPrint('[Bridge] Services ready, injecting bridge interface');
            await _injectBridgeInterface();
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('WebView error: ${error.description}');
          },
        ),
      )
      ..addJavaScriptChannel(
        'shellBridge',
        onMessageReceived: (JavaScriptMessage message) {
          _handleBridgeMessage(message.message);
        },
      );

    // Enable debugging on Android
    if (_webViewController.platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(true);
      (_webViewController.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }
  }

  /// Injects bridge interface into WebView JavaScript context
  Future<void> _injectBridgeInterface() async {
    // Inject bridge adapter that connects JavaScript to Flutter channel
    // Uses JavaScriptChannel for async two-way communication
    await _webViewController.runJavaScript('''
      (function() {
        // Store pending callbacks
        let callbackId = 0;
        const pendingCallbacks = {};

        // Listen for responses from Flutter
        window.addEventListener('flutterResponse', function(event) {
          const { id, result } = event.detail;
          const callback = pendingCallbacks[id];
          if (callback) {
            callback.resolve(result);
            delete pendingCallbacks[id];
          }
        });

        // Store reference to native channel before creating the bridge object
        const nativeChannel = window.shellBridge;

        // Create bridge interface with all methods
        window.shellBridge = {
          // Internal method to call Flutter bridge
          _call: function(method, args) {
            return new Promise((resolve, reject) => {
              const id = ++callbackId;
              pendingCallbacks[id] = { resolve, reject };

              // Set timeout for request
              setTimeout(() => {
                if (pendingCallbacks[id]) {
                  delete pendingCallbacks[id];
                  reject(new Error('Bridge call timeout: ' + method));
                }
              }, 30000); // 30 second timeout

              // Send to Flutter via JavaScriptChannel (using native channel reference)
              const message = JSON.stringify({ id, method, args: args || {} });
              nativeChannel.postMessage(message);
            });
          },

          // Phase 1: Core session methods
          getBootstrapCode: function() {
            return this._call('getBootstrapCode', {});
          },

          redeemBootstrap: function(bootstrapCode) {
            return this._call('redeemBootstrap', { bootstrapCode });
          },

          validateSession: function(sessionId) {
            return this._call('validateSession', { sessionId });
          },

          revokeSession: function(sessionId) {
            return this._call('revokeSession', { sessionId });
          },

          getPositionContext: function() {
            return this._call('getPositionContext', {});
          },

          unmountModule: function(sessionId) {
            return this._call('unmountModule', { sessionId });
          },

          // Phase 2: Module loading
          loadPositionModule: function(moduleId, version) {
            return this._call('loadPositionModule', { moduleId, version });
          },

          // Phase 3: Offline methods (old - deprecated)
          getNetworkState: function() {
            return this._call('getNetworkState', {});
          },

          getPendingSyncCount: function() {
            return this._call('getPendingSyncCount', {});
          },

          submitOfflineTransaction: function(args) {
            return this._call('submitOfflineTransaction', args);
          },

          // Phase 3.5: NEW OFFLINE-FIRST METHODS
          submitTransaction: function(args) {
            return this._call('submitTransaction', args);
          },

          getTransactionHistory: function() {
            return this._call('getTransactionHistory', {});
          },

          getSyncStatus: function() {
            return this._call('getSyncStatus', {});
          },

          forceSyncNow: function() {
            return this._call('forceSyncNow', {});
          },

          // Phase 5: Scanner methods
          scanBarcode: function() {
            return this._call('scanBarcode', {});
          },

          scanQRCode: function() {
            return this._call('scanQRCode', {});
          },

          // Phase 5.1: Photo methods
          capturePhoto: function(lineItemId) {
            return this._call('capturePhoto', { lineItemId: lineItemId || 'default' });
          },

          deletePhoto: function(photoPath) {
            return this._call('deletePhoto', { photoPath: photoPath });
          },

          listPhotos: function(lineItemId) {
            return this._call('listPhotos', { lineItemId: lineItemId || 'default' });
          }
        };

        console.log('[Shell] Bridge interface injected with all methods');
      })();
    ''');
  }

  /// Handles bridge messages from JavaScript
  Future<void> _handleBridgeMessage(String message) async {
    try {
      print('[Bridge] ===== NEW MESSAGE FROM JS =====');
      print('[Bridge] Message received: $message');

      // Parse incoming message
      final Map<String, dynamic> request = json.decode(message);
      final int id = request['id'] as int;
      final String method = request['method'] as String;
      final Map<String, dynamic>? args = request['args'] as Map<String, dynamic>?;

      print('[Bridge] Parsed: id=$id, method=$method, args=$args');

      // CRITICAL FIX: Check if services are initialized before calling bridge methods
      // This prevents MissingPluginException when bridge is called during initialization
      if (!_servicesInitialized) {
        print('[Bridge] ⚠️ Services not initialized yet! Method: $method');
        await _sendBridgeResponse(id, {
          'success': false,
          'error': 'Services still initializing, please wait and try again...',
        });
        return;
      }

      print('[Bridge] Services initialized: $_servicesInitialized');
      print('[Bridge] ShellBridge instance: ${_shellBridge.hashCode}');
      print('[Bridge] Routing method: $method with args: $args');

      // CRITICAL FIX: Call ShellBridge methods directly, not through MethodChannel
      // MethodChannel.invokeMethod() is for Flutter->Native, not Flutter->Flutter
      try {
        final MethodCall call = MethodCall(method, args);
        final result = await _shellBridge.handleMethodCall(call);

        print('[Bridge] Method call SUCCESS: $result');
        // Send response back to JavaScript
        await _sendBridgeResponse(id, result);
      } catch (e) {
        print('[Bridge] ❌ Method call error: $e');
        print('[Bridge] Error type: ${e.runtimeType}');
        await _sendBridgeResponse(id, {
          'success': false,
          'error': e.toString(),
        });
      }
    } catch (e) {
      print('[Bridge] ❌ Message parsing error: $e');
    }
  }

  /// Sends response back to JavaScript
  Future<void> _sendBridgeResponse(int id, dynamic result) async {
    final responseScript = '''
      window.dispatchEvent(new CustomEvent('flutterResponse', {
        detail: ${json.encode({
          'id': id,
          'result': result,
        })}
      }));
    ''';

    await _webViewController.runJavaScript(responseScript);
  }

  /// Handles authentication flow
  Future<void> _handleLogin() async {
    if (!_servicesInitialized) {
      setState(() {
        _statusMessage = 'Services still initializing, please wait...';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Authenticating...';
    });

    try {
      // Step 1: Authenticate user (mock system browser flow)
      final success = await _authService.authenticateUser(
        username: _usernameController.text,
        password: _passwordController.text,
      );

      if (!success) {
        throw Exception('Authentication failed');
      }

      setState(() {
        _statusMessage = 'Resolving position...';
      });

      // Step 2: Resolve user's position
      final username = await _authService.getCurrentUsername();
      if (username == null) {
        throw Exception('Cannot determine user');
      }

      _currentPosition = await _positionResolver.resolvePosition(username);
      _shellBridge.setCurrentPosition(_currentPosition!);

      // Phase 3.5: Show module selection instead of auto-loading WebView
      setState(() {
        _isAuthenticated = true;
        _showModuleSelection = true;
        _statusMessage = 'Select a position module';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: $e';
      });
      debugPrint('Login error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Phase 3.5: Handles module selection callback
  Future<void> _handleModuleSelected(String moduleId) async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Loading module: $moduleId';
      _selectedModuleId = moduleId;
    });

    try {
      await _loadRuntimeHost(moduleId);

      setState(() {
        _showModuleSelection = false;
        _isLoading = false;
        _statusMessage = 'Module loaded: $moduleId - Position: ${_currentPosition!.positionName}';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _showModuleSelection = true; // Stay on selection screen on error
        _statusMessage = 'Error loading module: $e';
      });
    }
  }

  /// Loads runtime host HTML in WebView with selected module
  Future<void> _loadRuntimeHost(String moduleId) async {
    // Phase 4: Load actual React module HTML from modules directory
    print('[RuntimeHost] Loading module: $moduleId');

    // Phase 3.5: Get module metadata from registry
    final moduleMetadata = await _moduleRegistry.getLatestVersion(moduleId);
    if (moduleMetadata == null) {
      throw Exception('Module not found: $moduleId');
    }

    // Construct path to module HTML file
    // Load from Flutter assets (in shell/assets/modules/)
    final modulePath = 'assets/modules/$moduleId/index.html';

    print('[RuntimeHost] Loading module from: $modulePath');

    try {
      // Load the module HTML file from assets
      await _webViewController.loadFlutterAsset(modulePath);

      print('[RuntimeHost] Module loaded successfully: $moduleId');
    } catch (e) {
      print('[RuntimeHost] Error loading module: $e');

      // Fallback to error page
      final errorHtml = '''
        <!DOCTYPE html>
        <html>
          <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Module Load Error</title>
            <style>
              body { font-family: sans-serif; padding: 20px; background: #f5f5f5; }
              .error { background: #ffebee; padding: 20px; border-radius: 8px; border-left: 4px solid #f44336; }
              h2 { color: #d32f2f; margin: 0 0 12px 0; }
              p { color: #666; margin: 8px 0; }
              code { background: #fff; padding: 2px 6px; border-radius: 3px; }
            </style>
          </head>
          <body>
            <div class="error">
              <h2>⚠️ Module Load Failed</h2>
              <p><strong>Module:</strong> <code>$moduleId</code></p>
              <p><strong>Error:</strong> $e</p>
              <p style="margin-top: 16px; font-size: 14px;">
                Check that the module HTML file exists at:<br>
                <code>$modulePath</code>
              </p>
            </div>
          </body>
        </html>
      ''';

      await _webViewController.loadHtmlString(errorHtml);
      throw Exception('Failed to load module: $e');
    }
  }

  /// Phase 3.5: Handles back navigation to module selection
  void _handleBackToModuleSelection() {
    setState(() {
      _showModuleSelection = true;
      _selectedModuleId = null;
      _statusMessage = 'Select a position module';
    });

    // Clear WebView content but don't invalidate session
    _webViewController.loadHtmlString('<html><body></body></html>');
  }

  /// Handles logout
  Future<void> _handleLogout() async {
    await _authService.logout();
    _shellBridge.clearPosition();

    setState(() {
      _isAuthenticated = false;
      _currentPosition = null;
      _showModuleSelection = false; // Phase 3.5: Clear selection state
      _selectedModuleId = null; // Phase 3.5: Clear selected module
      _statusMessage = 'Logged out';
    });

    // Clear WebView
    await _webViewController.loadHtmlString('<html><body></body></html>');
  }

  @override
  Widget build(BuildContext context) {
    // Set scanner context for navigation
    if (_servicesInitialized) {
      _scannerBridgeExtension.setContext(context);
      _photoBridgeExtension.setContext(context);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Foundry Shell'),
        actions: [
          if (_isAuthenticated)
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _handleLogout,
              tooltip: 'Logout',
            ),
        ],
      ),
      body: Column(
        children: [
          // Status bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: _isAuthenticated ? Colors.green.shade700 : Colors.blue.shade700,
            child: Text(
              _statusMessage,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),

          // Main content area
          Expanded(
            child: _buildMainContent(),
          ),
        ],
      ),
    );
  }

  /// Phase 3.5: Builds main content based on state
  Widget _buildMainContent() {
    if (!_isAuthenticated) {
      return _buildLoginForm();
    }

    if (_showModuleSelection) {
      return ModuleSelectionScreen(
        currentPosition: _currentPosition!,
        onModuleSelected: _handleModuleSelected,
      );
    }

    return _buildWebViewContainer();
  }

  /// Builds login form
  Widget _buildLoginForm() {
    return Center(
      child: Card(
        margin: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Mock Authentication',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Enter any credentials to simulate system browser auth',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: (_isLoading || !_servicesInitialized) ? null : _handleLogin,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_servicesInitialized ? 'Login' : 'Initializing...'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds WebView container
  Widget _buildWebViewContainer() {
    return Column(
      children: [
        // Position info bar with back button (Phase 3.5)
        if (_currentPosition != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: Colors.grey.shade200,
            child: Row(
              children: [
                // Back button to return to module selection
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _handleBackToModuleSelection,
                  tooltip: 'Back to module selection',
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Position: ${_currentPosition!.positionName}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Module: $_selectedModuleId | Org: ${_currentPosition!.orgId}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

        // WebView
        Expanded(
          child: WebViewWidget(controller: _webViewController),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
